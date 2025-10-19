--[[
    Storage.lua
    
    Storage module with AceDB integration for persistent data management.
    Handles rotation storage, profile management, and data migration.
    
    Implements the modular interface contract for plugin architecture.
]]

local ADDON_NAME = "DRC"

-- Create the Storage module
local Storage = DRC_CreateModule({
    name = "Storage",
    version = "1.0.0",
    description = "Persistent storage with AceDB and JSON serialization"
})

-- Module state
Storage.core = nil
Storage.db = nil
Storage.jsonUtil = nil

-- Database schema version for migration
Storage.SCHEMA_VERSION = 1

-- Default database structure
local defaults = {
    profile = {
        rotations = {},
        settings = {
            schemaVersion = 1,
            enableSounds = true,
            debugMode = false,
            defaultKeybind = nil,
            uiScale = 1.0,
            lastModified = nil
        },
        metadata = {
            created = nil,
            profileName = "Default"
        }
    }
}

--[[
    Module Lifecycle Methods
]]

function Storage:Initialize(core)
    self.core = core
    self._initialized = false
    
    -- Get JSON utility
    self.jsonUtil = _G.DRC_JSONUtil
    if not self.jsonUtil then
        core:PrintError("Storage module requires JSONUtil")
        return false
    end
    
    -- Initialize AceDB
    self.db = LibStub("AceDB-3.0"):New("DRCDB", defaults, true)
    
    if not self.db then
        core:PrintError("Failed to initialize database")
        return false
    end
    
    -- Set up profile callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileCopied")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
    
    -- Initialize metadata if this is a new profile
    if not self.db.profile.metadata.created then
        self.db.profile.metadata.created = time()
        self.db.profile.metadata.profileName = self.db:GetCurrentProfile()
    end
    
    -- Perform data migration if needed
    self:MigrateData()
    
    self._initialized = true
    core:Print("Storage module initialized")
    
    return true
end

function Storage:Enable()
    if not self._initialized then
        return false
    end
    
    self._enabled = true
    self.core:Print("Storage module enabled")
    
    return true
end

function Storage:Disable()
    if not self._enabled then
        return true
    end
    
    -- Save any pending changes
    if self.db then
        self.db.profile.settings.lastModified = time()
    end
    
    self._enabled = false
    self.core:Print("Storage module disabled")
    
    return true
end

function Storage:GetAPI()
    return {
        -- rotation operations
        Saverotation = function(...) return self:Saverotation(...) end,
        Loadrotation = function(...) return self:Loadrotation(...) end,
        Deleterotation = function(...) return self:Deleterotation(...) end,
        GetAllrotations = function(...) return self:GetAllrotations(...) end,
        rotationExists = function(...) return self:rotationExists(...) end,
        
        -- Settings operations
        GetSetting = function(...) return self:GetSetting(...) end,
        SetSetting = function(...) return self:SetSetting(...) end,
        GetAllSettings = function(...) return self:GetAllSettings(...) end,
        
        -- Profile operations
        GetCurrentProfile = function(...) return self:GetCurrentProfile(...) end,
        SetProfile = function(...) return self:SetProfile(...) end,
        GetProfiles = function(...) return self:GetProfiles(...) end,
        CreateProfile = function(...) return self:CreateProfile(...) end,
        DeleteProfile = function(...) return self:DeleteProfile(...) end,
        CopyProfile = function(...) return self:CopyProfile(...) end,
        ResetProfile = function(...) return self:ResetProfile(...) end,
        
        -- Import/Export operations
        Exportrotation = function(...) return self:Exportrotation(...) end,
        Importrotation = function(...) return self:Importrotation(...) end,
        ExportAllrotations = function(...) return self:ExportAllrotations(...) end,
        
        -- Utility operations
        GetDatabaseStats = function(...) return self:GetDatabaseStats(...) end
    }
end

function Storage:GetDependencies()
    return {}
end

--[[
    rotation Operations
]]

-- Save a rotation to the database
-- @param rotation: rotation table with id, name, commands, metadata, settings
-- @return success: boolean indicating if save succeeded
-- @return errorMessage: Error message if save failed
function Storage:Saverotation(rotation)
    if not self._enabled then
        return false, "Storage module not enabled"
    end
    
    -- Validate rotation structure
    local valid, err = self:Validaterotation(rotation)
    if not valid then
        return false, "Invalid rotation: " .. err
    end
    
    -- Ensure rotation has required fields
    if not rotation.id then
        rotation.id = self:GeneraterotationId(rotation.name)
    end
    
    -- Update metadata
    if not rotation.metadata then
        rotation.metadata = {}
    end
    rotation.metadata.modified = time()
    
    if not rotation.metadata.created then
        rotation.metadata.created = time()
    end
    
    -- Save to database
    self.db.profile.rotations[rotation.id] = rotation
    self.db.profile.settings.lastModified = time()
    
    -- Broadcast event
    self.core:BroadcastEvent("rotation_SAVED", {
        rotationId = rotation.id,
        rotationName = rotation.name
    })
    
    return true
end

-- Load a rotation from the database
-- @param rotationId: Unique rotation identifier
-- @return rotation: rotation table or nil if not found
function Storage:Loadrotation(rotationId)
    if not self._enabled then
        return nil
    end
    
    return self.db.profile.rotations[rotationId]
end

-- Delete a rotation from the database
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if delete succeeded
function Storage:Deleterotation(rotationId)
    if not self._enabled then
        return false
    end
    
    if not self.db.profile.rotations[rotationId] then
        return false
    end
    
    local rotationName = self.db.profile.rotations[rotationId].name
    self.db.profile.rotations[rotationId] = nil
    self.db.profile.settings.lastModified = time()
    
    -- Broadcast event
    self.core:BroadcastEvent("rotation_DELETED", {
        rotationId = rotationId,
        rotationName = rotationName
    })
    
    return true
end

-- Get all rotations from the database
-- @return rotations: Table of all rotations keyed by id
function Storage:GetAllrotations()
    if not self._enabled then
        return {}
    end
    
    return self.db.profile.rotations
end

-- Check if a rotation exists
-- @param rotationId: Unique rotation identifier
-- @return boolean: true if rotation exists
function Storage:rotationExists(rotationId)
    if not self._enabled then
        return false
    end
    
    return self.db.profile.rotations[rotationId] ~= nil
end

--[[
    Settings Operations
]]

-- Get a setting value
-- @param key: Setting key
-- @return value: Setting value or nil
function Storage:GetSetting(key)
    if not self._enabled then
        return nil
    end
    
    return self.db.profile.settings[key]
end

-- Set a setting value
-- @param key: Setting key
-- @param value: Setting value
-- @return success: boolean indicating if set succeeded
function Storage:SetSetting(key, value)
    if not self._enabled then
        return false
    end
    
    self.db.profile.settings[key] = value
    self.db.profile.settings.lastModified = time()
    
    -- Broadcast event
    self.core:BroadcastEvent("SETTING_CHANGED", {
        key = key,
        value = value
    })
    
    return true
end

-- Get all settings
-- @return settings: Table of all settings
function Storage:GetAllSettings()
    if not self._enabled then
        return {}
    end
    
    return self.db.profile.settings
end

--[[
    Profile Operations
]]

-- Get current profile name
-- @return string: Current profile name
function Storage:GetCurrentProfile()
    if not self.db then
        return nil
    end
    
    return self.db:GetCurrentProfile()
end

-- Set active profile
-- @param profileName: Profile name to activate
-- @return success: boolean indicating if profile change succeeded
function Storage:SetProfile(profileName)
    if not self.db then
        return false
    end
    
    self.db:SetProfile(profileName)
    return true
end

-- Get list of all profiles
-- @return profiles: Array of profile names
function Storage:GetProfiles()
    if not self.db then
        return {}
    end
    
    return self.db:GetProfiles()
end

-- Create a new profile
-- @param profileName: Name for the new profile
-- @return success: boolean indicating if profile creation succeeded
function Storage:CreateProfile(profileName)
    if not self.db then
        return false
    end
    
    self.db:SetProfile(profileName)
    self.db.profile.metadata.created = time()
    self.db.profile.metadata.profileName = profileName
    
    return true
end

-- Delete a profile
-- @param profileName: Profile name to delete
-- @return success: boolean indicating if profile deletion succeeded
function Storage:DeleteProfile(profileName)
    if not self.db then
        return false
    end
    
    -- Don't allow deleting the current profile
    if profileName == self.db:GetCurrentProfile() then
        return false
    end
    
    self.db:DeleteProfile(profileName)
    return true
end

-- Copy a profile
-- @param sourceProfile: Source profile name
-- @param targetProfile: Target profile name (optional, defaults to current)
-- @return success: boolean indicating if profile copy succeeded
function Storage:CopyProfile(sourceProfile, targetProfile)
    if not self.db then
        return false
    end
    
    if targetProfile then
        self.db:SetProfile(targetProfile)
    end
    
    self.db:CopyProfile(sourceProfile)
    return true
end

-- Reset current profile to defaults
-- @return success: boolean indicating if profile reset succeeded
function Storage:ResetProfile()
    if not self.db then
        return false
    end
    
    self.db:ResetProfile()
    
    -- Reinitialize metadata
    self.db.profile.metadata.created = time()
    self.db.profile.metadata.profileName = self.db:GetCurrentProfile()
    
    return true
end

--[[
    Profile Callbacks
]]

function Storage:OnProfileChanged(event, database, newProfileKey)
    self.core:Print("Profile changed to: " .. newProfileKey)
    self.core:BroadcastEvent("PROFILE_CHANGED", {
        profileName = newProfileKey
    })
end

function Storage:OnProfileCopied(event, database, sourceProfileKey)
    self.core:Print("Profile copied from: " .. sourceProfileKey)
    self.core:BroadcastEvent("PROFILE_COPIED", {
        sourceProfile = sourceProfileKey
    })
end

function Storage:OnProfileReset(event, database)
    self.core:Print("Profile reset to defaults")
    self.core:BroadcastEvent("PROFILE_RESET", {})
end

--[[
    Import/Export Operations
]]

-- Export a rotation to JSON string
-- @param rotationId: Unique rotation identifier
-- @return success: boolean indicating if export succeeded
-- @return result: JSON string if success, error message if failure
function Storage:Exportrotation(rotationId)
    local rotation = self:Loadrotation(rotationId)
    if not rotation then
        return false, "rotation not found"
    end
    
    -- Create export structure
    local exportData = {
        formatVersion = "1.0",
        exportDate = date("%Y-%m-%dT%H:%M:%SZ", time()),
        rotations = { rotation },
        metadata = {
            exportedBy = ADDON_NAME .. " v1.0.0",
            totalrotations = 1
        }
    }
    
    -- Encode to JSON
    local success, jsonString, errorCode = self.jsonUtil:Encode(exportData)
    if not success then
        return false, jsonString
    end
    
    return true, jsonString
end

-- Import a rotation from JSON string
-- @param jsonString: JSON string containing rotation data
-- @return success: boolean indicating if import succeeded
-- @return result: Imported rotation or error message
function Storage:Importrotation(jsonString)
    -- Decode JSON
    local success, data, errorCode = self.jsonUtil:Decode(jsonString)
    if not success then
        return false, data
    end
    
    -- Validate import structure
    if not data.rotations or type(data.rotations) ~= "table" then
        return false, "Invalid import format: missing rotations"
    end
    
    if #data.rotations == 0 then
        return false, "No rotations found in import data"
    end
    
    -- Import first rotation (for single rotation import)
    local rotation = data.rotations[1]
    
    -- Validate rotation
    local valid, err = self:Validaterotation(rotation)
    if not valid then
        return false, "Invalid rotation data: " .. err
    end
    
    -- Check for name conflicts
    local existingId = self:FindrotationByName(rotation.name)
    if existingId then
        -- Generate unique name
        local baseName = rotation.name
        local counter = 1
        repeat
            rotation.name = baseName .. " (" .. counter .. ")"
            counter = counter + 1
            existingId = self:FindrotationByName(rotation.name)
        until not existingId
    end
    
    -- Generate new ID
    rotation.id = self:GeneraterotationId(rotation.name)
    
    -- Save rotation
    local saveSuccess, saveErr = self:Saverotation(rotation)
    if not saveSuccess then
        return false, saveErr
    end
    
    return true, rotation
end

-- Export all rotations to JSON string
-- @return success: boolean indicating if export succeeded
-- @return result: JSON string if success, error message if failure
function Storage:ExportAllrotations()
    local rotations = {}
    for id, rotation in pairs(self.db.profile.rotations) do
        table.insert(rotations, rotation)
    end
    
    if #rotations == 0 then
        return false, "No rotations to export"
    end
    
    -- Create export structure
    local exportData = {
        formatVersion = "1.0",
        exportDate = date("%Y-%m-%dT%H:%M:%SZ", time()),
        rotations = rotations,
        metadata = {
            exportedBy = ADDON_NAME .. " v1.0.0",
            totalrotations = #rotations
        }
    }
    
    -- Encode to JSON
    local success, jsonString, errorCode = self.jsonUtil:Encode(exportData)
    if not success then
        return false, jsonString
    end
    
    return true, jsonString
end

--[[
    Validation and Utility Methods
]]

-- Validate rotation structure
-- @param rotation: rotation table to validate
-- @return valid: boolean indicating if rotation is valid
-- @return errorMessage: Error message if invalid
function Storage:Validaterotation(rotation)
    if type(rotation) ~= "table" then
        return false, "rotation must be a table"
    end
    
    if not rotation.name or type(rotation.name) ~= "string" or rotation.name:trim() == "" then
        return false, "rotation must have a non-empty name"
    end
    
    if not rotation.commands or type(rotation.commands) ~= "table" then
        return false, "rotation must have a commands array"
    end
    
    if #rotation.commands == 0 then
        return false, "rotation must have at least one command"
    end
    
    -- Validate each command is a string
    for i, command in ipairs(rotation.commands) do
        if type(command) ~= "string" then
            return false, "Command " .. i .. " must be a string"
        end
    end
    
    return true
end

-- Generate a unique rotation ID
-- @param name: rotation name
-- @return string: Unique rotation ID
function Storage:GeneraterotationId(name)
    local baseName = name:lower():gsub("[^a-z0-9]", "_")
    local id = baseName
    local counter = 1
    
    while self.db.profile.rotations[id] do
        id = baseName .. "_" .. counter
        counter = counter + 1
    end
    
    return id
end

-- Find rotation by name
-- @param name: rotation name to search for
-- @return rotationId: rotation ID if found, nil otherwise
function Storage:FindrotationByName(name)
    for id, rotation in pairs(self.db.profile.rotations) do
        if rotation.name == name then
            return id
        end
    end
    return nil
end

-- Get database statistics
-- @return stats: Table with database statistics
function Storage:GetDatabaseStats()
    local rotationCount = 0
    local totalCommands = 0
    
    for id, rotation in pairs(self.db.profile.rotations) do
        rotationCount = rotationCount + 1
        totalCommands = totalCommands + #rotation.commands
    end
    
    return {
        rotationCount = rotationCount,
        totalCommands = totalCommands,
        currentProfile = self:GetCurrentProfile(),
        profileCount = #self:GetProfiles(),
        schemaVersion = self.db.profile.settings.schemaVersion,
        lastModified = self.db.profile.settings.lastModified
    }
end

--[[
    Data Migration
]]

-- Migrate data from older schema versions
function Storage:MigrateData()
    local currentVersion = self.db.profile.settings.schemaVersion or 0
    
    if currentVersion < self.SCHEMA_VERSION then
        self.core:Print("Migrating database from version " .. currentVersion .. " to " .. self.SCHEMA_VERSION)
        
        -- Perform migrations
        if currentVersion < 1 then
            self:MigrateToV1()
        end
        
        -- Update schema version
        self.db.profile.settings.schemaVersion = self.SCHEMA_VERSION
        self.core:Print("Database migration complete")
    end
end

-- Migrate to schema version 1
function Storage:MigrateToV1()
    -- Initial schema, no migration needed
    -- Future migrations would go here
    self.core:Print("Initialized schema version 1")
end

return Storage


