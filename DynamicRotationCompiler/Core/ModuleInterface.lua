--[[
    ModuleInterface.lua
    
    Defines the standard interface contract that all modules must implement.
    This ensures consistent module behavior and enables the plugin architecture.
]]

local ADDON_NAME = "DRC"

-- Module Interface Template
-- All modules should implement these methods to be compatible with the core registry
DRC_ModuleInterface = {
    -- Initialize the module with core reference
    -- @param core: Reference to the core addon object
    -- @return boolean: true if initialization successful
    Initialize = function(self, core)
        error("Module must implement Initialize(core)")
    end,
    
    -- Enable the module and start its operations
    -- Called after all modules are initialized
    -- @return boolean: true if enable successful
    Enable = function(self)
        error("Module must implement Enable()")
    end,
    
    -- Disable the module and cleanup resources
    -- Called when addon is disabled or reloaded
    -- @return boolean: true if disable successful
    Disable = function(self)
        error("Module must implement Disable()")
    end,
    
    -- Get the public API exposed by this module
    -- @return table: Public methods and properties
    GetAPI = function(self)
        error("Module must implement GetAPI()")
    end,
    
    -- Get list of module dependencies
    -- @return table: Array of module names this module depends on
    GetDependencies = function(self)
        return {}
    end,
    
    -- Get module metadata
    -- @return table: Module name, version, description
    GetMetadata = function(self)
        return {
            name = "Unknown",
            version = "1.0.0",
            description = "No description provided"
        }
    end
}

-- Helper function to create a new module that implements the interface
function DRC_CreateModule(metadata)
    local module = {}
    
    -- Copy interface methods as defaults
    for k, v in pairs(DRC_ModuleInterface) do
        module[k] = v
    end
    
    -- Store metadata
    module._metadata = metadata or {}
    module._enabled = false
    module._initialized = false
    
    -- Override GetMetadata to return stored metadata
    module.GetMetadata = function(self)
        return self._metadata
    end
    
    return module
end

-- Validate that a module implements the required interface
function DRC_ValidateModule(module)
    if type(module) ~= "table" then
        return false, "Module must be a table"
    end
    
    local requiredMethods = {
        "Initialize",
        "Enable", 
        "Disable",
        "GetAPI",
        "GetDependencies",
        "GetMetadata"
    }
    
    for _, method in ipairs(requiredMethods) do
        if type(module[method]) ~= "function" then
            return false, "Module missing required method: " .. method
        end
    end
    
    return true
end

