--[[
    Core.lua
    
    Core addon framework with module registry and lifecycle management.
    Implements a lightweight plugin architecture for modular development.
]]

local ADDON_NAME = "DynamicRotationCompiler"

-- Initialize the addon using Ace3 framework
DRC = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, 
    "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Module registry
DRC.modules = {}
DRC.moduleLoadOrder = {}
DRC.interfaces = {}

-- Event subscribers for inter-module communication
DRC.eventSubscribers = {}

-- Addon state
DRC.initialized = false
DRC.enabled = false

--[[
    Addon Lifecycle Methods
]]

function DRC:OnInitialize()
    self:Print("Initializing " .. ADDON_NAME .. "...")
    
    -- Initialize will be called when addon is loaded
    -- Database and core systems setup happens here
    
    -- Register modules
    self:RegisterModules()
    
    -- Initialize all modules
    if not self:InitializeAllModules() then
        self:PrintError("Failed to initialize modules")
        return
    end
    
    self.initialized = true
    
    self:Print(ADDON_NAME .. " initialized. Type /drc for commands.")
end

-- Register all addon modules
function DRC:RegisterModules()
    -- Storage module
    if Storage then
        self:Print("Registering Storage module...")
        self:RegisterModule("Storage", Storage)
    else
        self:PrintError("Storage module not found")
    end
    
    -- RotationEngine module
    if RotationEngine then
        self:Print("Registering RotationEngine module...")
        self:RegisterModule("RotationEngine", RotationEngine, {"Storage"})
    else
        self:PrintError("RotationEngine module not found")
    end
    
    -- UI module
    if UI then
        self:Print("Registering UI module...")
        self:RegisterModule("UI", UI, {"Storage", "RotationEngine"})
    else
        self:PrintError("UI module not found")
    end
end

function DRC:OnEnable()
    self:Print("Enabling " .. ADDON_NAME .. "...")
    
    -- Enable all registered modules
    self:EnableAllModules()
    
    self.enabled = true
    self:Print(ADDON_NAME .. " enabled.")
end

function DRC:OnDisable()
    self:Print("Disabling " .. ADDON_NAME .. "...")
    
    -- Disable all modules in reverse order
    self:DisableAllModules()
    
    self.enabled = false
    self:Print(ADDON_NAME .. " disabled.")
end

--[[
    Module Registry Methods
]]

-- Register a new module with the core system
-- @param name: Unique module identifier
-- @param module: Module table implementing ModuleInterface
-- @param dependencies: Optional array of module names this module depends on
-- @return boolean: true if registration successful
function DRC:RegisterModule(name, module, dependencies)
    if not name or type(name) ~= "string" then
        self:PrintError("Module name must be a non-empty string")
        return false
    end
    
    if self.modules[name] then
        self:PrintError("Module '" .. name .. "' is already registered")
        return false
    end
    
    -- Validate module implements required interface
    local valid, err = DRC_ValidateModule(module)
    if not valid then
        self:PrintError("Module '" .. name .. "' validation failed: " .. err)
        return false
    end
    
    -- Store module
    self.modules[name] = {
        instance = module,
        dependencies = dependencies or module:GetDependencies() or {},
        initialized = false,
        enabled = false
    }
    
    self:Print("Registered module: " .. name)
    return true
end

-- Get a registered module instance
-- @param name: Module identifier
-- @return module instance or nil
function DRC:GetModule(name)
    local moduleData = self.modules[name]
    if not moduleData then
        self:PrintError("Module '" .. name .. "' not found")
        return nil
    end
    
    return moduleData.instance
end

-- Check if a module is registered
-- @param name: Module identifier
-- @return boolean
function DRC:HasModule(name)
    return self.modules[name] ~= nil
end

-- Unload a module safely
-- @param name: Module identifier
-- @return boolean: true if unload successful
function DRC:UnloadModule(name)
    local moduleData = self.modules[name]
    if not moduleData then
        return false
    end
    
    -- Disable if enabled
    if moduleData.enabled then
        self:DisableModule(name)
    end
    
    -- Remove from registry
    self.modules[name] = nil
    
    -- Remove from load order
    for i, moduleName in ipairs(self.moduleLoadOrder) do
        if moduleName == name then
            table.remove(self.moduleLoadOrder, i)
            break
        end
    end
    
    self:Print("Unloaded module: " .. name)
    return true
end

--[[
    Module Lifecycle Methods
]]

-- Initialize all registered modules in dependency order
function DRC:InitializeAllModules()
    -- Resolve dependency order
    local loadOrder = self:ResolveDependencyOrder()
    if not loadOrder then
        self:PrintError("Failed to resolve module dependencies")
        return false
    end
    
    self.moduleLoadOrder = loadOrder
    
    -- Initialize modules in order
    for _, name in ipairs(loadOrder) do
        if not self:InitializeModule(name) then
            self:PrintError("Failed to initialize module: " .. name)
            return false
        end
    end
    
    return true
end

-- Initialize a specific module
-- @param name: Module identifier
-- @return boolean: true if initialization successful
function DRC:InitializeModule(name)
    local moduleData = self.modules[name]
    if not moduleData then
        return false
    end
    
    if moduleData.initialized then
        return true
    end
    
    -- Initialize dependencies first
    for _, depName in ipairs(moduleData.dependencies) do
        if not self:InitializeModule(depName) then
            self:PrintError("Failed to initialize dependency '" .. depName .. "' for module '" .. name .. "'")
            return false
        end
    end
    
    -- Initialize the module
    local success, err = pcall(function()
        return moduleData.instance:Initialize(self)
    end)
    
    if not success then
        self:PrintError("Error initializing module '" .. name .. "': " .. tostring(err))
        return false
    end
    
    moduleData.initialized = true
    return true
end

-- Enable all initialized modules
function DRC:EnableAllModules()
    for _, name in ipairs(self.moduleLoadOrder) do
        self:EnableModule(name)
    end
end

-- Enable a specific module
-- @param name: Module identifier
-- @return boolean: true if enable successful
function DRC:EnableModule(name)
    local moduleData = self.modules[name]
    if not moduleData then
        return false
    end
    
    if not moduleData.initialized then
        self:PrintError("Cannot enable uninitialized module: " .. name)
        return false
    end
    
    if moduleData.enabled then
        return true
    end
    
    local success, err = pcall(function()
        return moduleData.instance:Enable()
    end)
    
    if not success then
        self:PrintError("Error enabling module '" .. name .. "': " .. tostring(err))
        return false
    end
    
    moduleData.enabled = true
    return true
end

-- Disable all modules in reverse order
function DRC:DisableAllModules()
    for i = #self.moduleLoadOrder, 1, -1 do
        local name = self.moduleLoadOrder[i]
        self:DisableModule(name)
    end
end

-- Disable a specific module
-- @param name: Module identifier  
-- @return boolean: true if disable successful
function DRC:DisableModule(name)
    local moduleData = self.modules[name]
    if not moduleData then
        return false
    end
    
    if not moduleData.enabled then
        return true
    end
    
    local success, err = pcall(function()
        return moduleData.instance:Disable()
    end)
    
    if not success then
        self:PrintError("Error disabling module '" .. name .. "': " .. tostring(err))
        return false
    end
    
    moduleData.enabled = false
    return true
end

--[[
    Dependency Resolution
]]

-- Resolve module load order based on dependencies
-- @return array of module names in load order, or nil if circular dependency detected
function DRC:ResolveDependencyOrder()
    local order = {}
    local visited = {}
    local visiting = {}
    
    local function visit(name)
        if visited[name] then
            return true
        end
        
        if visiting[name] then
            self:PrintError("Circular dependency detected involving module: " .. name)
            return false
        end
        
        visiting[name] = true
        
        local moduleData = self.modules[name]
        if moduleData then
            for _, depName in ipairs(moduleData.dependencies) do
                if not self.modules[depName] then
                    self:PrintError("Module '" .. name .. "' depends on unregistered module: " .. depName)
                    return false
                end
                
                if not visit(depName) then
                    return false
                end
            end
        end
        
        visiting[name] = false
        visited[name] = true
        table.insert(order, name)
        
        return true
    end
    
    -- Visit all modules
    for name in pairs(self.modules) do
        if not visit(name) then
            return nil
        end
    end
    
    return order
end

--[[
    Event System for Inter-Module Communication
]]

-- Broadcast an event to all subscribed modules
-- @param event: Event name
-- @param data: Event data payload
function DRC:BroadcastEvent(event, data)
    local subscribers = self.eventSubscribers[event]
    if not subscribers then
        return
    end
    
    for _, callback in ipairs(subscribers) do
        local success, err = pcall(callback, event, data)
        if not success then
            self:PrintError("Error in event callback for '" .. event .. "': " .. tostring(err))
        end
    end
end

-- Subscribe to an event
-- @param event: Event name
-- @param callback: Function to call when event is broadcast
function DRC:SubscribeEvent(event, callback)
    if not self.eventSubscribers[event] then
        self.eventSubscribers[event] = {}
    end
    
    table.insert(self.eventSubscribers[event], callback)
end

-- Unsubscribe from an event
-- @param event: Event name
-- @param callback: Callback function to remove
function DRC:UnsubscribeEvent(event, callback)
    local subscribers = self.eventSubscribers[event]
    if not subscribers then
        return
    end
    
    for i, cb in ipairs(subscribers) do
        if cb == callback then
            table.remove(subscribers, i)
            break
        end
    end
end

--[[
    Utility Methods
]]

-- Print error message
function DRC:PrintError(message)
    self:Print("|cFFFF0000Error:|r " .. message)
end

-- Register slash commands
DRC:RegisterChatCommand("drc", "SlashCommand")
DRC:RegisterChatCommand("DRC", "SlashCommand")

function DRC:SlashCommand(input)
    if not input or input:trim() == "" then
        self:Print("Dynamic Rotation Compiler v1.0.0")
        self:Print("Commands:")
        self:Print("  /drc help - Show this help")
        self:Print("  /drc show - Open the main UI")
        self:Print("  /drc modules - List registered modules")
        self:Print("  /drc status - Show addon status")
        return
    end
    
    local command = input:lower():trim()
    
    if command == "help" then
        self:SlashCommand("")
    elseif command == "show" or command == "ui" or command == "open" then
        -- Open the UI
        local uiModule = self:GetModule("UI")
        if uiModule then
            local api = uiModule:GetAPI()
            if api and api.ShowMainWindow then
                api.ShowMainWindow()
            else
                self:PrintError("UI module API not available")
            end
        else
            self:PrintError("UI module not loaded")
        end
    elseif command == "modules" then
        self:Print("Registered modules:")
        for name, data in pairs(self.modules) do
            local status = data.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
            self:Print("  " .. name .. " - " .. status)
        end
    elseif command == "status" then
        self:Print("Addon Status:")
        self:Print("  Initialized: " .. tostring(self.initialized))
        self:Print("  Enabled: " .. tostring(self.enabled))
        self:Print("  Modules: " .. self:GetModuleCount())
    else
        self:Print("Unknown command. Type /drc help for available commands.")
    end
end

-- Get count of registered modules
function DRC:GetModuleCount()
    local count = 0
    for _ in pairs(self.modules) do
        count = count + 1
    end
    return count
end



