--[[
    UI.lua
    
    UI module with plugin architecture for managing addon interface.
    Provides window management, layout system, and event handling.
    Supports theme plugins and swappable UI backends.
    
    Implements the modular interface contract for plugin architecture.
]]

local ADDON_NAME = "DRC"

-- Create the UI module
local UI = DRC_CreateModule({
    name = "UI",
    version = "1.0.0",
    description = "Modular UI system with plugin architecture and theme support"
})

-- Module state
UI.core = nil
UI.storage = nil
UI.rotationEngine = nil

-- UI state
UI.windows = {}
UI.activeTheme = "default"
UI.themes = {}
UI.backends = {}
UI.activeBackend = "aceGUI"

-- Window registry
UI.windowRegistry = {}

-- Event handlers
UI.eventHandlers = {}

--[[
    Module Lifecycle Methods
]]

function UI:Initialize(core)
    self.core = core
    self._initialized = false
    
    -- Initialize registries
    self.themes = {}
    self.backends = {}
    self.windows = {}
    self.windowRegistry = {}
    self.eventHandlers = {}
    
    -- Register default theme directly
    self.themes["default"] = self:GetDefaultTheme()
    self.activeTheme = "default"
    
    -- Register AceGUI backend directly
    self.backends["aceGUI"] = self:CreateAceGUIBackend()
    self.activeBackend = "aceGUI"
    
    -- Subscribe to storage events
    core:SubscribeEvent("ROTATION_SAVED", function(event, data)
        if self.OnRotationSaved then
            self:OnRotationSaved(data)
        end
    end)
    
    core:SubscribeEvent("ROTATION_DELETED", function(event, data)
        if self.OnRotationDeleted then
            self:OnRotationDeleted(data)
        end
    end)
    
    core:SubscribeEvent("PROFILE_CHANGED", function(event, data)
        if self.OnProfileChanged then
            self:OnProfileChanged(data)
        end
    end)
    
    self._initialized = true
    core:Print("UI module initialized")
    
    return true
end

function UI:Enable()
    if not self._initialized then
        return false
    end
    
    -- Get module dependencies
    self.storage = self.core:GetModule("Storage")
    if not self.storage then
        self.core:PrintError("UI module requires Storage module")
        return false
    end
    
    self.rotationEngine = self.core:GetModule("RotationEngine")
    if not self.rotationEngine then
        self.core:PrintError("UI module requires RotationEngine module")
        return false
    end
    
    -- Register window definitions
    if UIWindows then
        UIWindows:RegisterAll(self)
    end
    
    -- Register settings window
    if UISettings then
        UISettings:RegisterAll(self, self.storage)
    end
    
    -- Register slash commands for UI
    self.core:RegisterChatCommand("drcui", function(input)
        self:HandleSlashCommand(input)
    end)
    
    self._enabled = true
    self.core:Print("UI module enabled")
    
    return true
end

function UI:Disable()
    if not self._enabled then
        return true
    end
    
    -- Close all open windows
    self:CloseAllWindows()
    
    self._enabled = false
    self.core:Print("UI module disabled")
    
    return true
end

function UI:GetAPI()
    return {
        -- Window management
        OpenWindow = function(...) return self:OpenWindow(...) end,
        CloseWindow = function(...) return self:CloseWindow(...) end,
        ToggleWindow = function(...) return self:ToggleWindow(...) end,
        IsWindowOpen = function(...) return self:IsWindowOpen(...) end,
        CloseAllWindows = function(...) return self:CloseAllWindows(...) end,
        
        -- Window registration
        RegisterWindow = function(...) return self:RegisterWindow(...) end,
        UnregisterWindow = function(...) return self:UnregisterWindow(...) end,
        
        -- Theme management
        RegisterTheme = function(...) return self:RegisterTheme(...) end,
        SetTheme = function(...) return self:SetTheme(...) end,
        GetTheme = function(...) return self:GetTheme(...) end,
        GetAvailableThemes = function(...) return self:GetAvailableThemes(...) end,
        
        -- Backend management
        RegisterBackend = function(...) return self:RegisterBackend(...) end,
        SetBackend = function(...) return self:SetBackend(...) end,
        GetBackend = function(...) return self:GetBackend(...) end,
        
        -- Event handling
        RegisterEventHandler = function(...) return self:RegisterEventHandler(...) end,
        UnregisterEventHandler = function(...) return self:UnregisterEventHandler(...) end,
        TriggerEvent = function(...) return self:TriggerEvent(...) end,
        
        -- Main UI entry points
        ShowMainWindow = function(...) return self:ShowMainWindow(...) end,
        ShowRotationEditor = function(...) return self:ShowRotationEditor(...) end,
        ShowSettings = function(...) return self:ShowSettings(...) end,
        ShowImportDialog = function(...) return self:ShowImportDialog(...) end,
        ShowExportDialog = function(...) return self:ShowExportDialog(...) end
    }
end

function UI:GetDependencies()
    return {"Storage", "RotationEngine"}
end

--[[
    Window Management
]]

-- Open a window by name
-- @param windowName: Name of the window to open
-- @param options: Optional table of window options
-- @return success: boolean indicating if window opened successfully
function UI:OpenWindow(windowName, options)
    if not self._enabled then
        return false
    end
    
    -- Check if window is registered
    local windowDef = self.windowRegistry[windowName]
    if not windowDef then
        self.core:PrintError("Window not registered: " .. windowName)
        return false
    end
    
    -- Check if window is already open
    if self.windows[windowName] then
        -- Bring to front
        self:BringWindowToFront(windowName)
        return true
    end
    
    -- Create window using active backend
    local backend = self.backends[self.activeBackend]
    if not backend then
        self.core:PrintError("No active UI backend")
        return false
    end
    
    -- Create window
    local window = backend:CreateWindow(windowDef, options)
    if not window then
        self.core:PrintError("Failed to create window: " .. windowName)
        return false
    end
    
    -- Store window reference
    self.windows[windowName] = window
    
    -- Trigger event
    self:TriggerEvent("WINDOW_OPENED", {
        windowName = windowName,
        window = window
    })
    
    return true
end

-- Close a window by name
-- @param windowName: Name of the window to close
-- @return success: boolean indicating if window closed successfully
function UI:CloseWindow(windowName)
    if not self._enabled then
        return false
    end
    
    local window = self.windows[windowName]
    if not window then
        return false
    end
    
    -- Close window using backend
    local backend = self.backends[self.activeBackend]
    if backend and backend.CloseWindow then
        backend:CloseWindow(window)
    end
    
    -- Remove window reference
    self.windows[windowName] = nil
    
    -- Trigger event
    self:TriggerEvent("WINDOW_CLOSED", {
        windowName = windowName
    })
    
    return true
end

-- Toggle a window (open if closed, close if open)
-- @param windowName: Name of the window to toggle
-- @param options: Optional table of window options
-- @return success: boolean indicating if toggle succeeded
function UI:ToggleWindow(windowName, options)
    if self:IsWindowOpen(windowName) then
        return self:CloseWindow(windowName)
    else
        return self:OpenWindow(windowName, options)
    end
end

-- Check if a window is open
-- @param windowName: Name of the window to check
-- @return boolean: true if window is open
function UI:IsWindowOpen(windowName)
    return self.windows[windowName] ~= nil
end

-- Close all open windows
function UI:CloseAllWindows()
    local windowNames = {}
    for name in pairs(self.windows) do
        table.insert(windowNames, name)
    end
    
    for _, name in ipairs(windowNames) do
        self:CloseWindow(name)
    end
end

-- Bring window to front
-- @param windowName: Name of the window
function UI:BringWindowToFront(windowName)
    local window = self.windows[windowName]
    if not window then
        return
    end
    
    local backend = self.backends[self.activeBackend]
    if backend and backend.BringToFront then
        backend:BringToFront(window)
    end
end

--[[
    Window Registration
]]

-- Register a window definition
-- @param windowName: Unique window identifier
-- @param windowDef: Window definition table
-- @return success: boolean indicating if registration succeeded
function UI:RegisterWindow(windowName, windowDef)
    if self.windowRegistry[windowName] then
        self.core:PrintError("Window already registered: " .. windowName)
        return false
    end
    
    -- Validate window definition
    if not windowDef.title then
        self.core:PrintError("Window definition must have a title")
        return false
    end
    
    if not windowDef.layout then
        self.core:PrintError("Window definition must have a layout function")
        return false
    end
    
    self.windowRegistry[windowName] = windowDef
    return true
end

-- Unregister a window definition
-- @param windowName: Window identifier
-- @return success: boolean indicating if unregistration succeeded
function UI:UnregisterWindow(windowName)
    if not self.windowRegistry[windowName] then
        return false
    end
    
    -- Close window if open
    if self:IsWindowOpen(windowName) then
        self:CloseWindow(windowName)
    end
    
    self.windowRegistry[windowName] = nil
    return true
end

--[[
    Theme Management
]]

-- Register a theme
-- @param themeName: Unique theme identifier
-- @param themeData: Theme definition table
-- @return success: boolean indicating if registration succeeded
function UI:RegisterTheme(themeName, themeData)
    if self.themes[themeName] then
        self.core:PrintError("Theme already registered: " .. themeName)
        return false
    end
    
    self.themes[themeName] = themeData
    return true
end

-- Set active theme
-- @param themeName: Theme identifier
-- @return success: boolean indicating if theme change succeeded
function UI:SetTheme(themeName)
    if not self.themes[themeName] then
        self.core:PrintError("Theme not found: " .. themeName)
        return false
    end
    
    self.activeTheme = themeName
    
    -- Trigger event
    self:TriggerEvent("THEME_CHANGED", {
        themeName = themeName
    })
    
    return true
end

-- Get active theme
-- @return theme: Active theme data
function UI:GetTheme()
    return self.themes[self.activeTheme]
end

-- Get list of available themes
-- @return themes: Array of theme names
function UI:GetAvailableThemes()
    local themeList = {}
    for name in pairs(self.themes) do
        table.insert(themeList, name)
    end
    return themeList
end

-- Get default theme definition
function UI:GetDefaultTheme()
    return {
        name = "Default",
        colors = {
            primary = {0.2, 0.2, 0.8, 1.0},
            secondary = {0.3, 0.3, 0.3, 1.0},
            background = {0.1, 0.1, 0.1, 0.9},
            text = {1.0, 1.0, 1.0, 1.0},
            success = {0.2, 0.8, 0.2, 1.0},
            warning = {0.8, 0.8, 0.2, 1.0},
            error = {0.8, 0.2, 0.2, 1.0}
        },
        fonts = {
            normal = "Fonts\\FRIZQT__.TTF",
            title = "Fonts\\FRIZQT__.TTF",
            mono = "Fonts\\ARIALN.TTF"
        },
        sizes = {
            titleFont = 14,
            normalFont = 12,
            smallFont = 10,
            padding = 10,
            spacing = 5
        }
    }
end

--[[
    Backend Management
]]

-- Register a UI backend
-- @param backendName: Unique backend identifier
-- @param backend: Backend implementation table
-- @return success: boolean indicating if registration succeeded
function UI:RegisterBackend(backendName, backend)
    if self.backends[backendName] then
        self.core:PrintError("Backend already registered: " .. backendName)
        return false
    end
    
    self.backends[backendName] = backend
    return true
end

-- Set active backend
-- @param backendName: Backend identifier
-- @return success: boolean indicating if backend change succeeded
function UI:SetBackend(backendName)
    if not self.backends[backendName] then
        self.core:PrintError("Backend not found: " .. backendName)
        return false
    end
    
    -- Close all windows before switching
    self:CloseAllWindows()
    
    self.activeBackend = backendName
    
    -- Trigger event
    self:TriggerEvent("BACKEND_CHANGED", {
        backendName = backendName
    })
    
    return true
end

-- Get active backend
-- @return backend: Active backend implementation
function UI:GetBackend()
    return self.backends[self.activeBackend]
end

--[[
    Event Handling
]]

-- Register an event handler
-- @param eventName: Event name
-- @param handler: Handler function
-- @return success: boolean indicating if registration succeeded
function UI:RegisterEventHandler(eventName, handler)
    if not self.eventHandlers[eventName] then
        self.eventHandlers[eventName] = {}
    end
    
    table.insert(self.eventHandlers[eventName], handler)
    return true
end

-- Unregister an event handler
-- @param eventName: Event name
-- @param handler: Handler function to remove
-- @return success: boolean indicating if unregistration succeeded
function UI:UnregisterEventHandler(eventName, handler)
    local handlers = self.eventHandlers[eventName]
    if not handlers then
        return false
    end
    
    for i, h in ipairs(handlers) do
        if h == handler then
            table.remove(handlers, i)
            return true
        end
    end
    
    return false
end

-- Trigger a UI event
-- @param eventName: Event name
-- @param data: Event data
function UI:TriggerEvent(eventName, data)
    local handlers = self.eventHandlers[eventName]
    if not handlers then
        return
    end
    
    for _, handler in ipairs(handlers) do
        local success, err = pcall(handler, eventName, data)
        if not success then
            self.core:PrintError("Error in UI event handler for '" .. eventName .. "': " .. tostring(err))
        end
    end
end

--[[
    AceGUI Backend Implementation
]]

function UI:CreateAceGUIBackend()
    local backend = {
        name = "AceGUI",
        version = "1.0.0"
    }
    
    -- Create window using AceGUI
    function backend:CreateWindow(windowDef, options)
        -- Note: This will be fully implemented when AceGUI-3.0 is added
        -- For now, return a placeholder
        
        local window = {
            name = windowDef.name or "Unnamed Window",
            title = windowDef.title,
            definition = windowDef,
            options = options or {},
            widgets = {},
            frame = nil
        }
        
        -- TODO: Implement actual AceGUI window creation
        -- local AceGUI = LibStub("AceGUI-3.0")
        -- window.frame = AceGUI:Create("Frame")
        -- window.frame:SetTitle(windowDef.title)
        -- window.frame:SetLayout("Flow")
        
        return window
    end
    
    -- Close window
    function backend:CloseWindow(window)
        if window.frame and window.frame.Release then
            window.frame:Release()
        end
    end
    
    -- Bring window to front
    function backend:BringToFront(window)
        if window.frame and window.frame.frame then
            window.frame.frame:Raise()
        end
    end
    
    return backend
end

--[[
    Main UI Entry Points
]]

-- Show main window
function UI:ShowMainWindow()
    return self:OpenWindow("main")
end

-- Show rotation editor
-- @param rotationId: Optional rotation ID to edit
function UI:ShowRotationEditor(rotationId)
    return self:OpenWindow("rotationEditor", {rotationId = rotationId})
end

-- Show settings panel
function UI:ShowSettings()
    return self:OpenWindow("settings")
end

-- Show import dialog
function UI:ShowImportDialog()
    return self:OpenWindow("import")
end

-- Show export dialog
-- @param rotationId: Optional rotation ID to export
function UI:ShowExportDialog(rotationId)
    return self:OpenWindow("export", {rotationId = rotationId})
end

--[[
    Storage Event Handlers
]]

function UI:OnRotationSaved(data)
    -- Refresh any open windows that display rotations
    self:TriggerEvent("ROTATION_LIST_CHANGED", data)
end

function UI:OnRotationDeleted(data)
    -- Refresh any open windows that display rotations
    self:TriggerEvent("ROTATION_LIST_CHANGED", data)
end

function UI:OnProfileChanged(data)
    -- Refresh all windows with new profile data
    self:TriggerEvent("PROFILE_CHANGED", data)
end

--[[
    Slash Command Handler
]]

function UI:HandleSlashCommand(input)
    if not input or input:trim() == "" then
        self:ShowMainWindow()
        return
    end
    
    local command = input:lower():trim()
    
    if command == "show" or command == "main" then
        self:ShowMainWindow()
    elseif command == "settings" or command == "config" then
        self:ShowSettings()
    elseif command == "new" or command == "create" then
        self:ShowRotationEditor()
    elseif command == "import" then
        self:ShowImportDialog()
    elseif command == "export" then
        self:ShowExportDialog()
    else
        self.core:Print("Unknown UI command. Available commands:")
        self.core:Print("  /drcui show - Show main window")
        self.core:Print("  /drcui settings - Show settings")
        self.core:Print("  /drcui new - Create new rotation")
        self.core:Print("  /drcui import - Import rotation")
        self.core:Print("  /drcui export - Export rotation")
    end
end

-- Export module globally for Core registration
UI = UI
return UI
