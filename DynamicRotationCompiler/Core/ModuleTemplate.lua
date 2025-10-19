--[[
    ModuleTemplate.lua
    
    Template for creating new modules that implement the ModuleInterface.
    Copy this file and replace the placeholder names and logic.
]]

-- Create a new module using the helper function
local ModuleName = MacroSequencer_CreateModule({
    name = "ModuleName",
    version = "1.0.0",
    description = "Description of what this module does"
})

-- Private state
local isInitialized = false
local isEnabled = false
local coreRef = nil

--[[
    Lifecycle Methods
]]

-- Initialize the module
-- @param core: Reference to MacroSequencer core addon
-- @return boolean: true if initialization successful
function ModuleName:Initialize(core)
    if isInitialized then
        return true
    end
    
    -- Store core reference
    coreRef = core
    
    -- Initialize module state
    -- TODO: Add initialization logic here
    
    isInitialized = true
    core:Print("ModuleName initialized")
    return true
end

-- Enable the module
-- @return boolean: true if enable successful
function ModuleName:Enable()
    if not isInitialized then
        return false
    end
    
    if isEnabled then
        return true
    end
    
    -- Start module operations
    -- TODO: Add enable logic here
    -- Example: Register events, start timers, show UI, etc.
    
    isEnabled = true
    coreRef:Print("ModuleName enabled")
    return true
end

-- Disable the module
-- @return boolean: true if disable successful
function ModuleName:Disable()
    if not isEnabled then
        return true
    end
    
    -- Stop module operations and cleanup
    -- TODO: Add disable logic here
    -- Example: Unregister events, stop timers, hide UI, etc.
    
    isEnabled = false
    coreRef:Print("ModuleName disabled")
    return true
end

--[[
    Public API
]]

-- Get the public API exposed by this module
-- @return table: Public methods that other modules can call
function ModuleName:GetAPI()
    return {
        -- Example public method
        DoSomething = function(param)
            if not isEnabled then
                return false, "Module not enabled"
            end
            
            -- TODO: Implement public method
            return true
        end,
        
        -- Example public getter
        GetStatus = function()
            return {
                initialized = isInitialized,
                enabled = isEnabled
            }
        end
    }
end

--[[
    Dependencies
]]

-- Declare module dependencies
-- @return table: Array of module names this module depends on
function ModuleName:GetDependencies()
    return {
        -- Example: "Storage", "SequenceEngine"
    }
end

--[[
    Private Methods
]]

-- Example private helper method
local function privateHelper()
    -- Private implementation details
end

--[[
    Event Handlers (if needed)
]]

-- Example event handler
local function OnSomeEvent(event, ...)
    if not isEnabled then
        return
    end
    
    -- Handle event
end

-- Register event handlers in Enable(), unregister in Disable()

--[[
    Module Registration
]]

-- Register this module with the core when the file loads
-- Uncomment when ready to use:
-- MacroSequencer:RegisterModule("ModuleName", ModuleName)
