# DRC Storage Module Tests

This directory contains unit tests for the Dynamic Rotation Compiler Storage module.

## Test Coverage

The test suite covers the following requirements:

### Requirement 1.3: Storage with JSON Serialization
- JSON encoding of rotation data
- JSON decoding of rotation data
- Handling malformed JSON
- Data integrity through export/import cycles

### Requirement 3.5: Profile Management
- Saving and loading rotations
- Profile switching
- Data isolation between profiles
- Profile copying
- Profile reset to defaults
- Settings persistence

### Error Handling
- Invalid rotation structures
- Missing required fields
- Empty or corrupted data
- Malformed JSON input
- Type validation

## Running Tests

### Prerequisites
- Lua 5.1 or compatible version installed
- All DRC dependencies available

### Windows
```batch
cd DynamicRotationCompiler
Tests\run_tests.bat
```

### Linux/Mac
```bash
cd DynamicRotationCompiler
lua Tests/Storage_Tests.lua
```

## Test Structure

The test suite uses a lightweight testing framework with the following features:

- **Test Suites**: Logical grouping of related tests
- **Assertions**: Various assertion methods for validation
- **Mocking**: Mock WoW API and Ace3 libraries for isolated testing
- **Error Handling**: Graceful handling of test failures with detailed messages

## Test Suites

### 1. JSON Serialization/Deserialization
Tests the core JSON functionality for import/export operations.

### 2. Profile Switching and Data Persistence
Tests profile management and data isolation between profiles.

### 3. Error Handling for Corrupted Data
Tests validation and error handling for invalid input data.

## Adding New Tests

To add new tests, follow this pattern:

```lua
TestFramework:Suite("Suite Name", function()
    TestFramework:Test("Test description", function()
        -- Test setup
        local storage = CreateStorageInstance()
        
        -- Test execution
        local result = storage:SomeMethod()
        
        -- Assertions
        TestFramework:Assert(condition, "Error message")
        TestFramework:AssertEqual(actual, expected, "Error message")
    end)
end)
```

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Storage Tests
  run: lua DynamicRotationCompiler/Tests/Storage_Tests.lua
```

## Notes

- Tests use mocked WoW API functions to run outside the game environment
- Each test creates a fresh Storage instance to ensure isolation
- Tests are designed to be fast and focused on core functionality
- Mock implementations simulate AceDB-3.0 behavior for profile management
