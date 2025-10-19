--[[
    Storage_Tests.lua
    
    Unit tests for the Storage module.
    Tests JSON serialization/deserialization, profile switching, and error handling.
    
    Requirements tested: 1.3, 3.5
]]

-- Mock WoW API functions for testing
local function SetupMockEnvironment()
    -- Mock LibStub
    _G.LibStub = _G.LibStub or {}
    
    -- Mock time function
    _G.time = _G.time or function() return os.time() end
    
    -- Mock date function
    _G.date = _G.date or function(format, timestamp) return os.date(format, timestamp) end
    
    -- Mock string trim function
    if not string.trim then
        string.trim = function(s)
            return s:match("^%s*(.-)%s*$")
        end
    end
    
    -- Mock AceDB-3.0
    local MockAceDB = {
        profiles = {},
        currentProfile = "Default"
    }
    
    function MockAceDB:New(name, defaults, defaultProfile)
        local db = {
            profile = self:DeepCopy(defaults.profile),
            callbacks = {},
            profiles = { Default = self:DeepCopy(defaults.profile) }
        }
        
        function db:GetCurrentProfile()
            return MockAceDB.currentProfile
        end
        
        function db:SetProfile(profileName)
            if not self.profiles[profileName] then
                self.profiles[profileName] = self:DeepCopy(defaults.profile)
            end
            MockAceDB.currentProfile = profileName
            self.profile = self.profiles[profileName]
            
            -- Trigger callback
            for _, callback in pairs(self.callbacks) do
                if callback.method == "OnProfileChanged" then
                    callback.handler[callback.method](callback.handler, "OnProfileChanged", self, profileName)
                end
            end
        end
        
        function db:GetProfiles()
            local profileList = {}
            for name in pairs(self.profiles) do
                table.insert(profileList, name)
            end
            return profileList
        end
        
        function db:DeleteProfile(profileName)
            if profileName ~= self:GetCurrentProfile() then
                self.profiles[profileName] = nil
            end
        end
        
        function db:CopyProfile(sourceProfile)
            local currentName = self:GetCurrentProfile()
            if self.profiles[sourceProfile] then
                self.profiles[currentName] = self:DeepCopy(self.profiles[sourceProfile])
                self.profile = self.profiles[currentName]
                
                -- Trigger callback
                for _, callback in pairs(self.callbacks) do
                    if callback.method == "OnProfileCopied" then
                        callback.handler[callback.method](callback.handler, "OnProfileCopied", self, sourceProfile)
                    end
                end
            end
        end
        
        function db:ResetProfile()
            local currentName = self:GetCurrentProfile()
            self.profiles[currentName] = self:DeepCopy(defaults.profile)
            self.profile = self.profiles[currentName]
            
            -- Trigger callback
            for _, callback in pairs(self.callbacks) do
                if callback.method == "OnProfileReset" then
                    callback.handler[callback.method](callback.handler, "OnProfileReset", self)
                end
            end
        end
        
        function db:RegisterCallback(handler, event, method)
            table.insert(self.callbacks, {
                handler = handler,
                event = event,
                method = method
            })
        end
        
        function db:DeepCopy(original)
            local copy
            if type(original) == "table" then
                copy = {}
                for key, value in pairs(original) do
                    copy[key] = self:DeepCopy(value)
                end
            else
                copy = original
            end
            return copy
        end
        
        return db
    end
    
    _G.LibStub = function(lib, silent)
        if lib == "AceDB-3.0" then
            return MockAceDB
        end
        return nil
    end
end

-- Test framework
local TestFramework = {
    tests = {},
    passed = 0,
    failed = 0,
    currentSuite = nil
}

function TestFramework:Suite(name, fn)
    self.currentSuite = name
    print("\n=== Test Suite: " .. name .. " ===")
    fn()
    self.currentSuite = nil
end

function TestFramework:Test(name, fn)
    local fullName = self.currentSuite and (self.currentSuite .. " - " .. name) or name
    local success, err = pcall(fn)
    
    if success then
        self.passed = self.passed + 1
        print("✓ " .. fullName)
    else
        self.failed = self.failed + 1
        print("✗ " .. fullName)
        print("  Error: " .. tostring(err))
    end
end

function TestFramework:Assert(condition, message)
    if not condition then
        error(message or "Assertion failed", 2)
    end
end

function TestFramework:AssertEqual(actual, expected, message)
    if actual ~= expected then
        local msg = message or string.format("Expected %s but got %s", tostring(expected), tostring(actual))
        error(msg, 2)
    end
end

function TestFramework:AssertNotNil(value, message)
    if value == nil then
        error(message or "Expected non-nil value", 2)
    end
end

function TestFramework:AssertNil(value, message)
    if value ~= nil then
        error(message or "Expected nil value", 2)
    end
end

function TestFramework:AssertTableEqual(actual, expected, message)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        error(message or "Both values must be tables", 2)
    end
    
    for k, v in pairs(expected) do
        if type(v) == "table" then
            self:AssertTableEqual(actual[k], v, message)
        else
            if actual[k] ~= v then
                error(message or string.format("Table mismatch at key %s: expected %s but got %s", 
                    tostring(k), tostring(v), tostring(actual[k])), 2)
            end
        end
    end
end

function TestFramework:Summary()
    print("\n=== Test Summary ===")
    print("Passed: " .. self.passed)
    print("Failed: " .. self.failed)
    print("Total: " .. (self.passed + self.failed))
    
    if self.failed == 0 then
        print("\n✓ All tests passed!")
        return true
    else
        print("\n✗ Some tests failed")
        return false
    end
end

-- Setup test environment
SetupMockEnvironment()

-- Load required modules
dofile("DynamicRotationCompiler/Libs/json.lua")
dofile("DynamicRotationCompiler/Core/ModuleInterface.lua")
dofile("DynamicRotationCompiler/Core/JSONUtil.lua")

-- Mock Core for testing
_G.DRC = {
    modules = {},
    eventSubscribers = {},
    
    Print = function(self, msg)
        -- Suppress output during tests
    end,
    
    PrintError = function(self, msg)
        -- Suppress output during tests
    end,
    
    BroadcastEvent = function(self, event, data)
        local subscribers = self.eventSubscribers[event]
        if subscribers then
            for _, callback in ipairs(subscribers) do
                callback(event, data)
            end
        end
    end,
    
    SubscribeEvent = function(self, event, callback)
        if not self.eventSubscribers[event] then
            self.eventSubscribers[event] = {}
        end
        table.insert(self.eventSubscribers[event], callback)
    end
}

-- Load Storage module
dofile("DynamicRotationCompiler/Modules/Storage.lua")

-- Initialize Storage module for testing
local function CreateStorageInstance()
    local storage = DRC_CreateModule({
        name = "Storage",
        version = "1.0.0",
        description = "Test instance"
    })
    
    -- Copy methods from Storage module
    for k, v in pairs(Storage) do
        if type(v) == "function" then
            storage[k] = v
        end
    end
    
    storage:Initialize(DRC)
    storage:Enable()
    
    return storage
end

--[[
    Test Suites
]]

-- Test Suite 1: JSON Serialization/Deserialization
TestFramework:Suite("JSON Serialization/Deserialization", function()
    
    TestFramework:Test("Should encode rotation to JSON", function()
        local storage = CreateStorageInstance()
        
        local rotation = {
            id = "test_rotation_1",
            name = "Test Rotation",
            commands = {"/cast Spell1", "/cast Spell2"},
            metadata = {
                class = "WARRIOR",
                created = time()
            }
        }
        
        local success, jsonString = storage:Exportrotation("test_rotation_1")
        
        -- First save the rotation
        storage:Saverotation(rotation)
        success, jsonString = storage:Exportrotation("test_rotation_1")
        
        TestFramework:Assert(success, "Export should succeed")
        TestFramework:AssertNotNil(jsonString, "JSON string should not be nil")
        TestFramework:Assert(type(jsonString) == "string", "Result should be a string")
        TestFramework:Assert(#jsonString > 0, "JSON string should not be empty")
    end)
    
    TestFramework:Test("Should decode JSON to rotation", function()
        local storage = CreateStorageInstance()
        
        local jsonString = [[{
            "formatVersion": "1.0",
            "exportDate": "2025-01-15T10:30:00Z",
            "rotations": [{
                "id": "test_rotation_2",
                "name": "Imported Rotation",
                "commands": ["/cast Spell1", "/cast Spell2"],
                "metadata": {"class": "MAGE"}
            }],
            "metadata": {"exportedBy": "DRC v1.0.0", "totalrotations": 1}
        }]]
        
        local success, rotation = storage:Importrotation(jsonString)
        
        TestFramework:Assert(success, "Import should succeed")
        TestFramework:AssertNotNil(rotation, "Rotation should not be nil")
        TestFramework:AssertEqual(rotation.name, "Imported Rotation", "Rotation name should match")
        TestFramework:AssertEqual(#rotation.commands, 2, "Should have 2 commands")
    end)
    
    TestFramework:Test("Should handle malformed JSON", function()
        local storage = CreateStorageInstance()
        
        local malformedJSON = [[{"invalid": json}]]
        
        local success, error = storage:Importrotation(malformedJSON)
        
        TestFramework:Assert(not success, "Import should fail for malformed JSON")
        TestFramework:AssertNotNil(error, "Error message should be provided")
    end)
    
    TestFramework:Test("Should preserve data through export/import cycle", function()
        local storage = CreateStorageInstance()
        
        local originalRotation = {
            id = "test_rotation_3",
            name = "Round Trip Test",
            commands = {"/cast Spell1", "/cast Spell2", "/use Item"},
            metadata = {
                class = "WARRIOR",
                spec = "Protection",
                created = time()
            },
            settings = {
                enabled = true,
                loopOnComplete = true
            }
        }
        
        -- Save original
        storage:Saverotation(originalRotation)
        
        -- Export
        local success, jsonString = storage:Exportrotation("test_rotation_3")
        TestFramework:Assert(success, "Export should succeed")
        
        -- Import
        success, importedRotation = storage:Importrotation(jsonString)
        TestFramework:Assert(success, "Import should succeed")
        
        -- Verify data integrity (name will be different due to conflict resolution)
        TestFramework:AssertEqual(#importedRotation.commands, #originalRotation.commands, 
            "Command count should match")
        TestFramework:AssertEqual(importedRotation.commands[1], originalRotation.commands[1], 
            "Commands should match")
    end)
end)

-- Test Suite 2: Profile Switching and Data Persistence
TestFramework:Suite("Profile Switching and Data Persistence", function()
    
    TestFramework:Test("Should save and load rotation", function()
        local storage = CreateStorageInstance()
        
        local rotation = {
            id = "persist_test_1",
            name = "Persistence Test",
            commands = {"/cast Spell1"}
        }
        
        local success = storage:Saverotation(rotation)
        TestFramework:Assert(success, "Save should succeed")
        
        local loaded = storage:Loadrotation("persist_test_1")
        TestFramework:AssertNotNil(loaded, "Loaded rotation should not be nil")
        TestFramework:AssertEqual(loaded.name, "Persistence Test", "Name should match")
    end)
    
    TestFramework:Test("Should switch profiles", function()
        local storage = CreateStorageInstance()
        
        -- Save rotation in default profile
        local rotation1 = {
            id = "profile_test_1",
            name = "Profile 1 Rotation",
            commands = {"/cast Spell1"}
        }
        storage:Saverotation(rotation1)
        
        -- Switch to new profile
        local success = storage:SetProfile("TestProfile")
        TestFramework:Assert(success, "Profile switch should succeed")
        TestFramework:AssertEqual(storage:GetCurrentProfile(), "TestProfile", 
            "Current profile should be TestProfile")
        
        -- Verify rotation from first profile is not in new profile
        local loaded = storage:Loadrotation("profile_test_1")
        TestFramework:AssertNil(loaded, "Rotation should not exist in new profile")
    end)
    
    TestFramework:Test("Should isolate data between profiles", function()
        local storage = CreateStorageInstance()
        
        -- Create rotation in default profile
        storage:SetProfile("Default")
        local rotation1 = {
            id = "isolation_test_1",
            name = "Default Profile Rotation",
            commands = {"/cast Spell1"}
        }
        storage:Saverotation(rotation1)
        
        -- Switch to new profile and create different rotation
        storage:SetProfile("Profile2")
        local rotation2 = {
            id = "isolation_test_2",
            name = "Profile2 Rotation",
            commands = {"/cast Spell2"}
        }
        storage:Saverotation(rotation2)
        
        -- Verify isolation
        TestFramework:AssertNotNil(storage:Loadrotation("isolation_test_2"), 
            "Profile2 rotation should exist")
        TestFramework:AssertNil(storage:Loadrotation("isolation_test_1"), 
            "Default rotation should not exist in Profile2")
        
        -- Switch back and verify
        storage:SetProfile("Default")
        TestFramework:AssertNotNil(storage:Loadrotation("isolation_test_1"), 
            "Default rotation should exist")
        TestFramework:AssertNil(storage:Loadrotation("isolation_test_2"), 
            "Profile2 rotation should not exist in Default")
    end)
    
    TestFramework:Test("Should copy profile data", function()
        local storage = CreateStorageInstance()
        
        -- Create source profile with data
        storage:SetProfile("SourceProfile")
        local rotation = {
            id = "copy_test_1",
            name = "Source Rotation",
            commands = {"/cast Spell1"}
        }
        storage:Saverotation(rotation)
        
        -- Create target profile and copy
        storage:SetProfile("TargetProfile")
        local success = storage:CopyProfile("SourceProfile")
        TestFramework:Assert(success, "Profile copy should succeed")
        
        -- Verify data was copied
        local copied = storage:Loadrotation("copy_test_1")
        TestFramework:AssertNotNil(copied, "Copied rotation should exist")
        TestFramework:AssertEqual(copied.name, "Source Rotation", "Rotation name should match")
    end)
    
    TestFramework:Test("Should reset profile to defaults", function()
        local storage = CreateStorageInstance()
        
        -- Add data to profile
        local rotation = {
            id = "reset_test_1",
            name = "Test Rotation",
            commands = {"/cast Spell1"}
        }
        storage:Saverotation(rotation)
        
        -- Reset profile
        local success = storage:ResetProfile()
        TestFramework:Assert(success, "Profile reset should succeed")
        
        -- Verify data was cleared
        local loaded = storage:Loadrotation("reset_test_1")
        TestFramework:AssertNil(loaded, "Rotation should not exist after reset")
        
        -- Verify settings were reset
        local rotations = storage:GetAllrotations()
        local count = 0
        for _ in pairs(rotations) do count = count + 1 end
        TestFramework:AssertEqual(count, 0, "Should have no rotations after reset")
    end)
    
    TestFramework:Test("Should persist settings across operations", function()
        local storage = CreateStorageInstance()
        
        -- Set a setting
        storage:SetSetting("testSetting", "testValue")
        
        -- Verify it persists
        local value = storage:GetSetting("testSetting")
        TestFramework:AssertEqual(value, "testValue", "Setting should persist")
        
        -- Save a rotation and verify setting still exists
        local rotation = {
            id = "setting_test_1",
            name = "Test",
            commands = {"/cast Spell1"}
        }
        storage:Saverotation(rotation)
        
        value = storage:GetSetting("testSetting")
        TestFramework:AssertEqual(value, "testValue", "Setting should persist after rotation save")
    end)
end)

-- Test Suite 3: Error Handling for Corrupted Data
TestFramework:Suite("Error Handling for Corrupted Data", function()
    
    TestFramework:Test("Should reject invalid rotation structure", function()
        local storage = CreateStorageInstance()
        
        local invalidRotation = {
            -- Missing name
            commands = {"/cast Spell1"}
        }
        
        local success, error = storage:Saverotation(invalidRotation)
        TestFramework:Assert(not success, "Should reject rotation without name")
        TestFramework:AssertNotNil(error, "Error message should be provided")
    end)
    
    TestFramework:Test("Should reject rotation with empty name", function()
        local storage = CreateStorageInstance()
        
        local invalidRotation = {
            name = "   ",
            commands = {"/cast Spell1"}
        }
        
        local success, error = storage:Saverotation(invalidRotation)
        TestFramework:Assert(not success, "Should reject rotation with empty name")
    end)
    
    TestFramework:Test("Should reject rotation without commands", function()
        local storage = CreateStorageInstance()
        
        local invalidRotation = {
            name = "Test Rotation"
            -- Missing commands
        }
        
        local success, error = storage:Saverotation(invalidRotation)
        TestFramework:Assert(not success, "Should reject rotation without commands")
    end)
    
    TestFramework:Test("Should reject rotation with empty commands array", function()
        local storage = CreateStorageInstance()
        
        local invalidRotation = {
            name = "Test Rotation",
            commands = {}
        }
        
        local success, error = storage:Saverotation(invalidRotation)
        TestFramework:Assert(not success, "Should reject rotation with empty commands")
    end)
    
    TestFramework:Test("Should reject rotation with non-string commands", function()
        local storage = CreateStorageInstance()
        
        local invalidRotation = {
            name = "Test Rotation",
            commands = {"/cast Spell1", 123, "/cast Spell3"}
        }
        
        local success, error = storage:Saverotation(invalidRotation)
        TestFramework:Assert(not success, "Should reject rotation with non-string command")
        TestFramework:Assert(error:find("must be a string"), "Error should mention string requirement")
    end)
    
    TestFramework:Test("Should handle import with missing rotations array", function()
        local storage = CreateStorageInstance()
        
        local invalidJSON = [[{
            "formatVersion": "1.0",
            "metadata": {"exportedBy": "DRC v1.0.0"}
        }]]
        
        local success, error = storage:Importrotation(invalidJSON)
        TestFramework:Assert(not success, "Should reject import without rotations")
        TestFramework:Assert(error:find("missing rotations"), "Error should mention missing rotations")
    end)
    
    TestFramework:Test("Should handle import with empty rotations array", function()
        local storage = CreateStorageInstance()
        
        local invalidJSON = [[{
            "formatVersion": "1.0",
            "rotations": [],
            "metadata": {"exportedBy": "DRC v1.0.0"}
        }]]
        
        local success, error = storage:Importrotation(invalidJSON)
        TestFramework:Assert(not success, "Should reject import with empty rotations")
        TestFramework:Assert(error:find("No rotations found"), "Error should mention no rotations")
    end)
    
    TestFramework:Test("Should handle corrupted JSON gracefully", function()
        local storage = CreateStorageInstance()
        
        local corruptedJSON = [[{
            "formatVersion": "1.0",
            "rotations": [{
                "name": "Test",
                "commands": ["/cast Spell1"
            }]
        }]]
        
        local success, error = storage:Importrotation(corruptedJSON)
        TestFramework:Assert(not success, "Should reject corrupted JSON")
        TestFramework:AssertNotNil(error, "Error message should be provided")
    end)
    
    TestFramework:Test("Should handle nil input gracefully", function()
        local storage = CreateStorageInstance()
        
        local success, error = storage:Importrotation(nil)
        TestFramework:Assert(not success, "Should reject nil input")
        TestFramework:AssertNotNil(error, "Error message should be provided")
    end)
    
    TestFramework:Test("Should handle empty string input", function()
        local storage = CreateStorageInstance()
        
        local success, error = storage:Importrotation("")
        TestFramework:Assert(not success, "Should reject empty string")
        TestFramework:AssertNotNil(error, "Error message should be provided")
    end)
    
    TestFramework:Test("Should validate rotation before saving", function()
        local storage = CreateStorageInstance()
        
        -- Test various invalid structures
        local testCases = {
            {data = nil, desc = "nil rotation"},
            {data = "not a table", desc = "string instead of table"},
            {data = 123, desc = "number instead of table"},
            {data = {}, desc = "empty table"}
        }
        
        for _, testCase in ipairs(testCases) do
            local success, error = storage:Saverotation(testCase.data)
            TestFramework:Assert(not success, "Should reject " .. testCase.desc)
        end
    end)
end)

-- Run all tests and print summary
local allPassed = TestFramework:Summary()

-- Return exit code
os.exit(allPassed and 0 or 1)
