--[[
    RotationEngine.lua
    
    Rotation engine module for managing rotation execution, validation, and state.
    Handles rotation data model, macro command validation, and execution state tracking.
    
    Implements the modular interface contract for plugin architecture.
]]

local ADDON_NAME = "DRC"

-- Create the RotationEngine module
local RotationEngine = DRC_CreateModule({
    name = "RotationEngine",
    version = "1.0.0",
    description = "Rotation execution engine with secure button management"
})

-- Module state
RotationEngine.core = nil
RotationEngine.storage = nil
RotationEngine.activeRotations = {}  -- Track active rotation states
RotationEngine.secureButtons = {}    -- Track secure button instances

-- Macro command validation patterns
local VALID_MACRO_COMMANDS = {
    "^/cast%s+.+",           -- /cast SpellName
    "^/use%s+.+",            -- /use ItemName or /use slot
    "^/castsequence%s+.+",   -- /castsequence spell1, spell2
    "^/stopcasting",         -- /stopcasting
    "^/startattack",         -- /startattack
    "^/stopattack",          -- /stopattack
    "^/petattack",           -- /petattack
    "^/petfollow",           -- /petfollow
    "^/target%s+.+",         -- /target UnitName
    "^/assist%s+.+",         -- /assist UnitName
    "^/focus%s+.+",          -- /focus UnitName
    "^/cleartarget",         -- /cleartarget
    "^/clearfocus",          -- /clearfocus
}

-- Unsafe commands that should not be allowed
local UNSAFE_COMMANDS = {
    "^/run%s+",              -- Lua execution
    "^/script%s+",           -- Lua execution
    "^/dump%s+",             -- Debug command
}

--[[
    Module Lifecycle Methods
]]

function RotationEngine:Initialize(core)
    self.core = core
    self._initialized = false
    
    -- Get Storage module dependency
    self.storage = core:GetModule("Storage")
    if not self.storage then
        core:PrintError("RotationEngine requires Storage module")
        return false
    end
    
    -- Initialize active rotation tracking
    self.activeRotations = {}
    self.secureButtons = {}
    
    self._initialized = true
    core:Print("RotationEngine module initialized")
    
    return true
end

function RotationEngine:Enable()
    if not self._initialized then
        return false
    end
    
    -- Register for combat events
    self.core:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        self:OnEnterCombat()
    end)
    
    self.core:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self:OnLeaveCombat()
    end)
    
    self._enabled = true
    self.core:Print("RotationEngine module enabled")
    
    return true
end

function RotationEngine:Disable()
    if not self._enabled then
        return true
    end
    
    -- Cleanup all secure buttons
    self:CleanupAllSecureButtons()
    
    -- Clear active rotations
    self.activeRotations = {}
    
    -- Unregister events
    self.core:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self.core:UnregisterEvent("PLAYER_REGEN_ENABLED")
    
    self._enabled = false
    self.core:Print("RotationEngine module disabled")
    
    return true
end

function RotationEngine:GetAPI()
    return {
        -- Rotation data model operations
        CreateRotation = function(...) return self:CreateRotation(...) end,
        ValidateRotation = function(...) return self:ValidateRotation(...) end,
        ValidateCommand = function(...) return self:ValidateCommand(...) end,
        
        -- Rotation state management
        GetRotationState = function(...) return self:GetRotationState(...) end,
        SetRotationEnabled = function(...) return self:SetRotationEnabled(...) end,
        ResetRotationState = function(...) return self:ResetRotationState(...) end,
        PauseRotation = function(...) return self:PauseRotation(...) end,
        ResumeRotation = function(...) return self:ResumeRotation(...) end,
        
        -- Execution operations
        ExecuteNextStep = function(...) return self:ExecuteNextStep(...) end,
        AdvanceRotation = function(...) return self:AdvanceRotation(...) end,
        ExecuteFromStart = function(...) return self:ExecuteFromStart(...) end,
        GetCurrentCommand = function(...) return self:GetCurrentCommand(...) end,
        GetRotationProgress = function(...) return self:GetRotationProgress(...) end,
        SkipToStep = function(...) return self:SkipToStep(...) end,
        GetAllActiveRotations = function(...) return self:GetAllActiveRotations(...) end,
        
        -- Secure button operations
        ConfigureSecureButton = function(...) return self:ConfigureSecureButton(...) end,
        UpdateSecureButton = function(...) return self:UpdateSecureButton(...) end,
        CleanupSecureButton = function(...) return self:CleanupSecureButton(...) end,
        CleanupAllSecureButtons = function(...) return self:CleanupAllSecureButtons(...) end,
        GetSecureButton = function(...) return self:GetSecureButton(...) end,
        HasSecureButton = function(...) return self:HasSecureButton(...) end,
    }
end

function RotationEngine:GetDependencies()
    return {"Storage"}
end

--[[
    Rotation Data Model Operations
]]

-- Create a new rotation with validation
-- @param name: Rotation display name
-- @param commands: Array of macro command strings
-- @param metadata: Optional metadata table
-- @return success: boolean indicating if creation succeeded
-- @return result: Rotation object if success, error message if failure
function RotationEngine:CreateRotation(name, commands, metadata)
    if not self._enabled then
        return false, "RotationEngine not enabled"
    end
    
    -- Validate inputs
    if not name or type(name) ~= "string" or name:trim() == "" then
        return false, "Rotation name must be a non-empty string"
    end
    
    if not commands or type(commands) ~= "table" or #commands == 0 then
        return false, "Rotation must have at least one command"
    end
    
    -- Validate all commands
    for i, command in ipairs(commands) do
        local valid, err = self:ValidateCommand(command)
        if not valid then
            return false, "Command " .. i .. ": " .. err
        end
    end
    
    -- Create rotation structure
    local rotation = {
        id = nil,  -- Will be generated by Storage module
        name = name,
        commands = commands,
        metadata = metadata or {},
        settings = {
            enabled = true,
            loopOnComplete = true,
            resetOnCombatEnd = false
        }
    }
    
    -- Set default metadata
    if not rotation.metadata.created then
        rotation.metadata.created = time()
    end
    rotation.metadata.modified = time()
    rotation.metadata.version = "1.0"
    
    -- Add player class/spec if available
    if _G.UnitClass then
        local _, class = _G.UnitClass("player")
        rotation.metadata.class = class
    end
    
    -- Validate the complete rotation structure
    local valid, err = self:ValidateRotation(rotation)
    if not valid then
        return false, err
    end
    
    -- Save to storage
    local storageAPI = self.storage:GetAPI()
    local success, saveErr = storageAPI.SaveRotation(rotation)
    if not success then
        return false, "Failed to save rotation: " .. saveErr
    end
    
    -- Initialize rotation state
    self:InitializeRotationState(rotation.id)
    
    return true, rotation
end

-- Validate a rotation structure
-- @param rotation: Rotation table to validate
-- @return valid: boolean indicating if rotation is valid
-- @return errorMessage: Error message if invalid
function RotationEngine:ValidateRotation(rotation)
    if type(rotation) ~= "table" then
        return false, "Rotation must be a table"
    end
    
    -- Validate name
    if not rotation.name or type(rotation.name) ~= "string" or rotation.name:trim() == "" then
        return false, "Rotation must have a non-empty name"
    end
    
    -- Validate commands array
    if not rotation.commands or type(rotation.commands) ~= "table" then
        return false, "Rotation must have a commands array"
    end
    
    if #rotation.commands == 0 then
        return false, "Rotation must have at least one command"
    end
    
    -- Validate each command
    for i, command in ipairs(rotation.commands) do
        if type(command) ~= "string" then
            return false, "Command " .. i .. " must be a string"
        end
        
        local valid, err = self:ValidateCommand(command)
        if not valid then
            return false, "Command " .. i .. ": " .. err
        end
    end
    
    -- Validate metadata (if present)
    if rotation.metadata and type(rotation.metadata) ~= "table" then
        return false, "Rotation metadata must be a table"
    end
    
    -- Validate settings (if present)
    if rotation.settings then
        if type(rotation.settings) ~= "table" then
            return false, "Rotation settings must be a table"
        end
        
        if rotation.settings.enabled ~= nil and type(rotation.settings.enabled) ~= "boolean" then
            return false, "Rotation enabled setting must be a boolean"
        end
        
        if rotation.settings.loopOnComplete ~= nil and type(rotation.settings.loopOnComplete) ~= "boolean" then
            return false, "Rotation loopOnComplete setting must be a boolean"
        end
        
        if rotation.settings.resetOnCombatEnd ~= nil and type(rotation.settings.resetOnCombatEnd) ~= "boolean" then
            return false, "Rotation resetOnCombatEnd setting must be a boolean"
        end
    end
    
    return true
end

-- Validate a single macro command
-- @param command: Command string to validate
-- @return valid: boolean indicating if command is valid
-- @return errorMessage: Error message if invalid
function RotationEngine:ValidateCommand(command)
    if type(command) ~= "string" then
        return false, "Command must be a string"
    end
    
    local trimmedCommand = command:trim()
    
    if trimmedCommand == "" then
        return false, "Command cannot be empty"
    end
    
    -- Check for unsafe commands
    for _, pattern in ipairs(UNSAFE_COMMANDS) do
        if trimmedCommand:match(pattern) then
            return false, "Unsafe command not allowed: " .. trimmedCommand:match("^(/[^%s]+)")
        end
    end
    
    -- Check if command matches valid patterns
    local isValid = false
    for _, pattern in ipairs(VALID_MACRO_COMMANDS) do
        if trimmedCommand:match(pattern) then
            isValid = true
            break
        end
    end
    
    if not isValid then
        return false, "Invalid or unsupported macro command syntax"
    end
    
    -- Additional validation for specific commands
    if trimmedCommand:match("^/cast%s+") then
        local spellName = trimmedCommand:match("^/cast%s+(.+)")
        if not spellName or spellName:trim() == "" then
            return false, "/cast requires a spell name"
        end
    end
    
    if trimmedCommand:match("^/use%s+") then
        local itemName = trimmedCommand:match("^/use%s+(.+)")
        if not itemName or itemName:trim() == "" then
            return false, "/use requires an item name or slot number"
        end
    end
    
    return true
end

--[[
    Rotation State Management
]]

-- Initialize rotation state tracking
-- @param rotationId: Unique rotation identifier
function RotationEngine:InitializeRotationState(rotationId)
    if not self.activeRotations[rotationId] then
        self.activeRotations[rotationId] = {
            currentStep = 1,
            enabled = true,
            lastExecuted = nil,
            executionCount = 0,
            inCombat = false
        }
    end
end

-- Get rotation state
-- @param rotationId: Unique rotation identifier
-- @return state: Rotation state table or nil if not found
function RotationEngine:GetRotationState(rotationId)
    if not self._enabled then
        return nil
    end
    
    -- Initialize state if it doesn't exist
    if not self.activeRotations[rotationId] then
        self:InitializeRotationState(rotationId)
    end
    
    return self.activeRotations[rotationId]
end

-- Set rotation enabled state
-- @param rotationId: Unique rotation identifier
-- @param enabled: Boolean enabled state
-- @return success: boolean indicating if state change succeeded
function RotationEngine:SetRotationEnabled(rotationId, enabled)
    if not self._enabled then
        return false
    end
    
    local state = self:GetRotationState(rotationId)
    if not state then
        return false
    end
    
    state.enabled = enabled
    
    -- Broadcast event
    self.core:BroadcastEvent("ROTATION_STATE_CHANGED", {
        rotationId = rotationId,
        enabled = enabled
    })
    
    return true
end

-- Reset rotation state to beginning
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if reset succeeded
function RotationEngine:ResetRotationState(rotationId)
    if not self._enabled then
        return false
    end
    
    local state = self:GetRotationState(rotationId)
    if not state then
        return false
    end
    
    state.currentStep = 1
    state.lastExecuted = nil
    
    -- Broadcast event
    self.core:BroadcastEvent("ROTATION_RESET", {
        rotationId = rotationId
    })
    
    return true
end

--[[
    Combat Event Handlers
]]

function RotationEngine:OnEnterCombat()
    -- Mark all active rotations as in combat
    for rotationId, state in pairs(self.activeRotations) do
        state.inCombat = true
    end
    
    self.core:BroadcastEvent("COMBAT_STARTED", {})
end

function RotationEngine:OnLeaveCombat()
    -- Mark all active rotations as out of combat
    for rotationId, state in pairs(self.activeRotations) do
        state.inCombat = false
        
        -- Reset rotations that have resetOnCombatEnd enabled
        local storageAPI = self.storage:GetAPI()
        local rotation = storageAPI.LoadRotation(rotationId)
        if rotation and rotation.settings and rotation.settings.resetOnCombatEnd then
            self:ResetRotationState(rotationId)
        end
    end
    
    self.core:BroadcastEvent("COMBAT_ENDED", {})
end

--[[
    Secure Button Management (Subtask 3.2)
    Implements Blizzard-compliant secure button creation and management
]]

-- Check if we're in combat
function RotationEngine:IsInCombat()
    if _G.InCombatLockdown then
        return _G.InCombatLockdown()
    end
    return false
end

-- Configure secure button for a rotation
-- @param rotationId: Unique rotation identifier
-- @param buttonName: Optional custom button name
-- @return success: boolean indicating if configuration succeeded
-- @return result: Button reference if success, error message if failure
function RotationEngine:ConfigureSecureButton(rotationId, buttonName)
    if not self._enabled then
        return false, "RotationEngine not enabled"
    end
    
    -- Cannot modify secure buttons during combat
    if self:IsInCombat() then
        return false, "Cannot configure secure buttons during combat"
    end
    
    -- Load rotation from storage
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return false, "Rotation not found: " .. rotationId
    end
    
    -- Validate rotation
    local valid, err = self:ValidateRotation(rotation)
    if not valid then
        return false, "Invalid rotation: " .. err
    end
    
    -- Generate button name if not provided
    if not buttonName then
        buttonName = "DRC_SecureButton_" .. rotationId
    end
    
    -- Check if button already exists
    local existingButton = self.secureButtons[rotationId]
    if existingButton then
        -- Cleanup existing button first
        self:CleanupSecureButton(rotationId)
    end
    
    -- Create secure button frame
    local button
    if _G.CreateFrame then
        button = _G.CreateFrame("Button", buttonName, nil, "SecureActionButtonTemplate")
    else
        -- Mock button for testing environment
        button = {
            name = buttonName,
            attributes = {},
            scripts = {},
            SetAttribute = function(self, key, value)
                self.attributes[key] = value
            end,
            GetAttribute = function(self, key)
                return self.attributes[key]
            end,
            SetScript = function(self, event, handler)
                self.scripts[event] = handler
            end,
            Hide = function(self) end,
            Show = function(self) end,
            RegisterForClicks = function(self, ...) end,
            SetParent = function(self, parent) end
        }
    end
    
    if not button then
        return false, "Failed to create secure button"
    end
    
    -- Configure button attributes for secure execution
    -- Set button type to macro
    button:SetAttribute("type", "macro")
    
    -- Get current step from rotation state
    local state = self:GetRotationState(rotationId)
    local currentStep = state and state.currentStep or 1
    
    -- Ensure step is within bounds
    if currentStep > #rotation.commands then
        currentStep = 1
    end
    
    -- Set the macro text to the current command
    local command = rotation.commands[currentStep]
    button:SetAttribute("macrotext", command)
    
    -- Store rotation metadata in button
    button:SetAttribute("_rotationId", rotationId)
    button:SetAttribute("_rotationName", rotation.name)
    button:SetAttribute("_totalSteps", #rotation.commands)
    button:SetAttribute("_currentStep", currentStep)
    
    -- Register for clicks
    if button.RegisterForClicks then
        button:RegisterForClicks("AnyUp")
    end
    
    -- Set up post-click handler (runs after the secure action)
    -- This advances the rotation to the next step
    if button.SetScript then
        button:SetScript("PostClick", function(self, mouseButton, down)
            -- This runs in restricted environment, so we use a callback
            RotationEngine:OnSecureButtonClicked(rotationId)
        end)
    end
    
    -- Store button reference
    self.secureButtons[rotationId] = {
        button = button,
        rotationId = rotationId,
        buttonName = buttonName,
        created = time()
    }
    
    -- Broadcast event
    self.core:BroadcastEvent("SECURE_BUTTON_CONFIGURED", {
        rotationId = rotationId,
        buttonName = buttonName
    })
    
    return true, button
end

-- Update secure button to current rotation step
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if update succeeded
function RotationEngine:UpdateSecureButton(rotationId)
    if not self._enabled then
        return false
    end
    
    -- Cannot modify secure buttons during combat
    if self:IsInCombat() then
        return false
    end
    
    local buttonData = self.secureButtons[rotationId]
    if not buttonData then
        return false
    end
    
    -- Load rotation
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return false
    end
    
    -- Get current step
    local state = self:GetRotationState(rotationId)
    local currentStep = state and state.currentStep or 1
    
    -- Ensure step is within bounds
    if currentStep > #rotation.commands then
        currentStep = 1
        if state then
            state.currentStep = 1
        end
    end
    
    -- Update button macro text
    local command = rotation.commands[currentStep]
    buttonData.button:SetAttribute("macrotext", command)
    buttonData.button:SetAttribute("_currentStep", currentStep)
    
    return true
end

-- Callback when secure button is clicked
-- @param rotationId: Unique rotation identifier
function RotationEngine:OnSecureButtonClicked(rotationId)
    -- This is called after the secure action executes
    -- We need to advance the rotation to the next step
    
    -- Get rotation state
    local state = self:GetRotationState(rotationId)
    if not state or not state.enabled then
        return
    end
    
    -- Update execution tracking
    state.lastExecuted = time()
    state.executionCount = state.executionCount + 1
    
    -- Broadcast event
    self.core:BroadcastEvent("ROTATION_STEP_EXECUTED", {
        rotationId = rotationId,
        step = state.currentStep,
        executionCount = state.executionCount
    })
    
    -- Note: We don't advance here because we can't modify secure buttons during combat
    -- The advancement will happen when UpdateSecureButton is called outside combat
    -- or through the ExecuteNextStep method
end

-- Cleanup secure button for a rotation
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if cleanup succeeded
function RotationEngine:CleanupSecureButton(rotationId)
    if not self._enabled then
        return false
    end
    
    -- Cannot modify secure buttons during combat
    if self:IsInCombat() then
        return false
    end
    
    local buttonData = self.secureButtons[rotationId]
    if not buttonData then
        return true  -- Already cleaned up
    end
    
    -- Hide and clear the button
    if buttonData.button then
        if buttonData.button.Hide then
            buttonData.button:Hide()
        end
        
        -- Clear attributes
        if buttonData.button.SetAttribute then
            buttonData.button:SetAttribute("type", nil)
            buttonData.button:SetAttribute("macrotext", nil)
            buttonData.button:SetAttribute("_rotationId", nil)
            buttonData.button:SetAttribute("_rotationName", nil)
        end
        
        -- Clear scripts
        if buttonData.button.SetScript then
            buttonData.button:SetScript("PostClick", nil)
        end
    end
    
    -- Remove from registry
    self.secureButtons[rotationId] = nil
    
    -- Broadcast event
    self.core:BroadcastEvent("SECURE_BUTTON_CLEANED", {
        rotationId = rotationId
    })
    
    return true
end

-- Cleanup all secure buttons
function RotationEngine:CleanupAllSecureButtons()
    if self:IsInCombat() then
        return false
    end
    
    local rotationIds = {}
    for rotationId in pairs(self.secureButtons) do
        table.insert(rotationIds, rotationId)
    end
    
    for _, rotationId in ipairs(rotationIds) do
        self:CleanupSecureButton(rotationId)
    end
    
    return true
end

-- Get secure button for a rotation
-- @param rotationId: Unique rotation identifier
-- @return button: Button reference or nil if not found
function RotationEngine:GetSecureButton(rotationId)
    local buttonData = self.secureButtons[rotationId]
    return buttonData and buttonData.button or nil
end

-- Check if rotation has a configured secure button
-- @param rotationId: Unique rotation identifier
-- @return boolean: true if button exists
function RotationEngine:HasSecureButton(rotationId)
    return self.secureButtons[rotationId] ~= nil
end

--[[
    Rotation Execution Engine (Subtask 3.3)
    Implements rotation step advancement, looping, and execution state tracking
]]

-- Execute next step in rotation
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if execution succeeded
-- @return result: Step number if success, error message if failure
function RotationEngine:ExecuteNextStep(rotationId)
    if not self._enabled then
        return false, "RotationEngine not enabled"
    end
    
    -- Load rotation from storage
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return false, "Rotation not found: " .. rotationId
    end
    
    -- Check if rotation is enabled
    if rotation.settings and rotation.settings.enabled == false then
        return false, "Rotation is disabled"
    end
    
    -- Get rotation state
    local state = self:GetRotationState(rotationId)
    if not state or not state.enabled then
        return false, "Rotation state is disabled"
    end
    
    -- Get current step
    local currentStep = state.currentStep
    
    -- Validate step is within bounds
    if currentStep < 1 or currentStep > #rotation.commands then
        -- Reset to beginning if out of bounds
        currentStep = 1
        state.currentStep = 1
    end
    
    -- Get the command for current step
    local command = rotation.commands[currentStep]
    
    -- Update execution tracking
    state.lastExecuted = time()
    state.executionCount = state.executionCount + 1
    
    -- Broadcast execution event
    self.core:BroadcastEvent("ROTATION_STEP_EXECUTING", {
        rotationId = rotationId,
        step = currentStep,
        command = command,
        totalSteps = #rotation.commands
    })
    
    -- Advance to next step
    local advanceSuccess, nextStep = self:AdvanceRotation(rotationId)
    if not advanceSuccess then
        return false, "Failed to advance rotation: " .. nextStep
    end
    
    -- Update secure button if it exists and we're not in combat
    if self:HasSecureButton(rotationId) and not self:IsInCombat() then
        self:UpdateSecureButton(rotationId)
    end
    
    -- Broadcast completion event
    self.core:BroadcastEvent("ROTATION_STEP_EXECUTED", {
        rotationId = rotationId,
        step = currentStep,
        nextStep = nextStep,
        command = command,
        executionCount = state.executionCount
    })
    
    return true, currentStep
end

-- Advance rotation to next step
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if advancement succeeded
-- @return result: Next step number if success, error message if failure
function RotationEngine:AdvanceRotation(rotationId)
    if not self._enabled then
        return false, "RotationEngine not enabled"
    end
    
    -- Load rotation from storage
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return false, "Rotation not found: " .. rotationId
    end
    
    -- Get rotation state
    local state = self:GetRotationState(rotationId)
    if not state then
        return false, "Rotation state not found"
    end
    
    local currentStep = state.currentStep
    local totalSteps = #rotation.commands
    
    -- Calculate next step
    local nextStep = currentStep + 1
    
    -- Check if we've reached the end
    if nextStep > totalSteps then
        -- Check loop setting
        local shouldLoop = true
        if rotation.settings and rotation.settings.loopOnComplete ~= nil then
            shouldLoop = rotation.settings.loopOnComplete
        end
        
        if shouldLoop then
            -- Loop back to beginning
            nextStep = 1
            
            -- Broadcast loop event
            self.core:BroadcastEvent("ROTATION_LOOPED", {
                rotationId = rotationId,
                executionCount = state.executionCount
            })
        else
            -- Stay at last step
            nextStep = totalSteps
            
            -- Broadcast completion event
            self.core:BroadcastEvent("ROTATION_COMPLETED", {
                rotationId = rotationId,
                executionCount = state.executionCount
            })
        end
    end
    
    -- Update state
    state.currentStep = nextStep
    
    -- Broadcast advancement event
    self.core:BroadcastEvent("ROTATION_ADVANCED", {
        rotationId = rotationId,
        previousStep = currentStep,
        currentStep = nextStep,
        totalSteps = totalSteps
    })
    
    return true, nextStep
end

-- Execute rotation from beginning
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if execution succeeded
function RotationEngine:ExecuteFromStart(rotationId)
    if not self._enabled then
        return false, "RotationEngine not enabled"
    end
    
    -- Reset rotation to beginning
    local resetSuccess = self:ResetRotationState(rotationId)
    if not resetSuccess then
        return false, "Failed to reset rotation"
    end
    
    -- Execute first step
    return self:ExecuteNextStep(rotationId)
end

-- Get current command for rotation
-- @param rotationId: Unique rotation identifier
-- @return command: Current command string or nil if not found
function RotationEngine:GetCurrentCommand(rotationId)
    if not self._enabled then
        return nil
    end
    
    -- Load rotation
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return nil
    end
    
    -- Get state
    local state = self:GetRotationState(rotationId)
    if not state then
        return nil
    end
    
    -- Get current step
    local currentStep = state.currentStep
    if currentStep < 1 or currentStep > #rotation.commands then
        return nil
    end
    
    return rotation.commands[currentStep]
end

-- Get rotation progress information
-- @param rotationId: Unique rotation identifier
-- @return progress: Table with progress information or nil if not found
function RotationEngine:GetRotationProgress(rotationId)
    if not self._enabled then
        return nil
    end
    
    -- Load rotation
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return nil
    end
    
    -- Get state
    local state = self:GetRotationState(rotationId)
    if not state then
        return nil
    end
    
    local totalSteps = #rotation.commands
    local currentStep = state.currentStep
    
    return {
        rotationId = rotationId,
        rotationName = rotation.name,
        currentStep = currentStep,
        totalSteps = totalSteps,
        currentCommand = rotation.commands[currentStep],
        progress = (currentStep / totalSteps) * 100,
        executionCount = state.executionCount,
        lastExecuted = state.lastExecuted,
        enabled = state.enabled,
        inCombat = state.inCombat
    }
end

-- Pause rotation execution
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if pause succeeded
function RotationEngine:PauseRotation(rotationId)
    return self:SetRotationEnabled(rotationId, false)
end

-- Resume rotation execution
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if resume succeeded
function RotationEngine:ResumeRotation(rotationId)
    return self:SetRotationEnabled(rotationId, true)
end

-- Skip to specific step in rotation
-- @param rotationId: Unique rotation identifier
-- @param stepNumber: Step number to skip to (1-based)
-- @return success: boolean indicating if skip succeeded
-- @return result: New step number if success, error message if failure
function RotationEngine:SkipToStep(rotationId, stepNumber)
    if not self._enabled then
        return false, "RotationEngine not enabled"
    end
    
    -- Cannot modify during combat
    if self:IsInCombat() then
        return false, "Cannot skip steps during combat"
    end
    
    -- Load rotation
    local storageAPI = self.storage:GetAPI()
    local rotation = storageAPI.LoadRotation(rotationId)
    if not rotation then
        return false, "Rotation not found"
    end
    
    -- Validate step number
    if type(stepNumber) ~= "number" or stepNumber < 1 or stepNumber > #rotation.commands then
        return false, "Invalid step number: must be between 1 and " .. #rotation.commands
    end
    
    -- Get state
    local state = self:GetRotationState(rotationId)
    if not state then
        return false, "Rotation state not found"
    end
    
    -- Update step
    local previousStep = state.currentStep
    state.currentStep = stepNumber
    
    -- Update secure button if exists
    if self:HasSecureButton(rotationId) then
        self:UpdateSecureButton(rotationId)
    end
    
    -- Broadcast event
    self.core:BroadcastEvent("ROTATION_STEP_SKIPPED", {
        rotationId = rotationId,
        previousStep = previousStep,
        currentStep = stepNumber
    })
    
    return true, stepNumber
end

-- Get all active rotations with their states
-- @return rotations: Table of rotation progress information
function RotationEngine:GetAllActiveRotations()
    if not self._enabled then
        return {}
    end
    
    local activeRotations = {}
    
    for rotationId, state in pairs(self.activeRotations) do
        local progress = self:GetRotationProgress(rotationId)
        if progress then
            table.insert(activeRotations, progress)
        end
    end
    
    return activeRotations
end

-- Export module globally for Core registration
RotationEngine = RotationEngine
return RotationEngine
