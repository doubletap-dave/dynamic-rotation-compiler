--[[
    JSONUtil.lua
    
    JSON utility wrapper with error handling and validation.
    Provides safe JSON serialization/deserialization for the addon.
    
    Uses json.lua by rxi (https://github.com/rxi/json.lua)
    Licensed under MIT License
]]

local ADDON_NAME = "DRC"

-- Load the json library
local json = LibStub and LibStub:GetLibrary("json", true)
if not json then
    -- Fallback: try to load directly if LibStub doesn't have it
    local loaded, jsonLib = pcall(require, "json")
    if loaded then
        json = jsonLib
    end
end

-- Create the JSON utility module
local JSONUtil = {}

-- Error codes for better error handling
JSONUtil.ErrorCodes = {
    ENCODE_FAILED = "ENCODE_FAILED",
    DECODE_FAILED = "DECODE_FAILED",
    INVALID_INPUT = "INVALID_INPUT",
    CIRCULAR_REFERENCE = "CIRCULAR_REFERENCE",
    INVALID_TYPE = "INVALID_TYPE",
    PARSE_ERROR = "PARSE_ERROR"
}

--[[
    Encode a Lua table to JSON string
    @param data: Lua table to encode
    @return success: boolean indicating if encoding succeeded
    @return result: JSON string if success, error message if failure
    @return errorCode: Error code if failure
]]
function JSONUtil:Encode(data)
    -- Validate input
    if data == nil then
        return false, "Cannot encode nil value", self.ErrorCodes.INVALID_INPUT
    end
    
    if type(data) ~= "table" and type(data) ~= "string" and type(data) ~= "number" and type(data) ~= "boolean" then
        return false, "Cannot encode type: " .. type(data), self.ErrorCodes.INVALID_TYPE
    end
    
    -- Check if json library is available
    if not json then
        return false, "JSON library not loaded", self.ErrorCodes.ENCODE_FAILED
    end
    
    -- Attempt to encode
    local success, result = pcall(function()
        return json.encode(data)
    end)
    
    if not success then
        local errorMsg = tostring(result)
        local errorCode = self.ErrorCodes.ENCODE_FAILED
        
        -- Detect specific error types
        if errorMsg:find("circular reference") then
            errorCode = self.ErrorCodes.CIRCULAR_REFERENCE
        elseif errorMsg:find("invalid table") or errorMsg:find("unexpected type") then
            errorCode = self.ErrorCodes.INVALID_TYPE
        end
        
        return false, "JSON encoding failed: " .. errorMsg, errorCode
    end
    
    return true, result
end

--[[
    Decode a JSON string to Lua table
    @param jsonString: JSON string to decode
    @return success: boolean indicating if decoding succeeded
    @return result: Lua table if success, error message if failure
    @return errorCode: Error code if failure
]]
function JSONUtil:Decode(jsonString)
    -- Validate input
    if not jsonString then
        return false, "Cannot decode nil value", self.ErrorCodes.INVALID_INPUT
    end
    
    if type(jsonString) ~= "string" then
        return false, "Input must be a string, got: " .. type(jsonString), self.ErrorCodes.INVALID_INPUT
    end
    
    if jsonString:trim() == "" then
        return false, "Cannot decode empty string", self.ErrorCodes.INVALID_INPUT
    end
    
    -- Check if json library is available
    if not json then
        return false, "JSON library not loaded", self.ErrorCodes.DECODE_FAILED
    end
    
    -- Attempt to decode
    local success, result = pcall(function()
        return json.decode(jsonString)
    end)
    
    if not success then
        local errorMsg = tostring(result)
        local errorCode = self.ErrorCodes.DECODE_FAILED
        
        -- Detect specific error types
        if errorMsg:find("line %d+ col %d+") then
            errorCode = self.ErrorCodes.PARSE_ERROR
        end
        
        return false, "JSON decoding failed: " .. errorMsg, errorCode
    end
    
    return true, result
end

--[[
    Validate if a string is valid JSON
    @param jsonString: String to validate
    @return boolean: true if valid JSON, false otherwise
    @return errorMessage: Error message if invalid
]]
function JSONUtil:Validate(jsonString)
    local success, result, errorCode = self:Decode(jsonString)
    if success then
        return true, nil
    else
        return false, result
    end
end

--[[
    Pretty print JSON with indentation (for debugging)
    @param data: Lua table to encode
    @param indent: Optional indent string (default: "  ")
    @return success: boolean indicating if encoding succeeded
    @return result: Pretty JSON string if success, error message if failure
]]
function JSONUtil:EncodePretty(data, indent)
    indent = indent or "  "
    
    -- First encode normally
    local success, jsonString, errorCode = self:Encode(data)
    if not success then
        return false, jsonString, errorCode
    end
    
    -- Add indentation (simple implementation)
    local level = 0
    local pretty = ""
    local inString = false
    local escaped = false
    
    for i = 1, #jsonString do
        local char = jsonString:sub(i, i)
        
        if not inString then
            if char == "{" or char == "[" then
                level = level + 1
                pretty = pretty .. char .. "\n" .. string.rep(indent, level)
            elseif char == "}" or char == "]" then
                level = level - 1
                pretty = pretty .. "\n" .. string.rep(indent, level) .. char
            elseif char == "," then
                pretty = pretty .. char .. "\n" .. string.rep(indent, level)
            elseif char == ":" then
                pretty = pretty .. char .. " "
            else
                pretty = pretty .. char
            end
            
            if char == '"' then
                inString = true
            end
        else
            pretty = pretty .. char
            
            if char == '"' and not escaped then
                inString = false
            end
            
            escaped = (char == "\\" and not escaped)
        end
    end
    
    return true, pretty
end

--[[
    Deep copy a table (useful before JSON operations)
    @param original: Table to copy
    @return table: Deep copy of the original table
]]
function JSONUtil:DeepCopy(original)
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

--[[
    Check if JSON library is available
    @return boolean: true if json library is loaded
]]
function JSONUtil:IsAvailable()
    return json ~= nil
end

--[[
    Get JSON library version
    @return string: Version string or "unknown"
]]
function JSONUtil:GetVersion()
    if json and json._version then
        return json._version
    end
    return "unknown"
end

-- Make JSONUtil globally accessible
_G.DRC_JSONUtil = JSONUtil

return JSONUtil

