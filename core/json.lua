local json = {}

local escapings = {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

local function isArray(tbl)
    local count = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        count = count + 1
    end
    for i = 1, count do
        if tbl[i] == nil then
            return false
        end
    end
    return true
end

local function encodeValue(value, buffer)
    local t = type(value)
    if t == "string" then
        buffer[#buffer + 1] = '"'
        buffer[#buffer + 1] = value:gsub('[%z\1-\31\\"]', function(c)
            return escapings[c] or string.format("\\u%04x", c:byte())
        end)
        buffer[#buffer + 1] = '"'
    elseif t == "number" then
        buffer[#buffer + 1] = tostring(value)
    elseif t == "boolean" then
        buffer[#buffer + 1] = value and "true" or "false"
    elseif t == "table" then
        if next(value) == nil then
            buffer[#buffer + 1] = "{}"
        elseif isArray(value) then
            buffer[#buffer + 1] = "["
            for i = 1, #value do
                if i > 1 then
                    buffer[#buffer + 1] = ","
                end
                encodeValue(value[i], buffer)
            end
            buffer[#buffer + 1] = "]"
        else
            buffer[#buffer + 1] = "{"
            local first = true
            for k, v in pairs(value) do
                if not first then
                    buffer[#buffer + 1] = ","
                end
                first = false
                encodeValue(tostring(k), buffer)
                buffer[#buffer + 1] = ":"
                encodeValue(v, buffer)
            end
            buffer[#buffer + 1] = "}"
        end
    elseif t == "nil" then
        buffer[#buffer + 1] = "null"
    else
        error("Unsupported type in json.encode: " .. t)
    end
end

function json.encode(value)
    local buffer = {}
    encodeValue(value, buffer)
    return table.concat(buffer)
end

local function skipWhitespace(str, index)
    local len = #str
    while index <= len do
        local c = str:sub(index, index)
        if c ~= " " and c ~= "\t" and c ~= "\n" and c ~= "\r" then
            break
        end
        index = index + 1
    end
    return index
end

local function parseString(str, index)
    index = index + 1
    local buffer = {}
    local len = #str
    while index <= len do
        local c = str:sub(index, index)
        if c == '"' then
            return table.concat(buffer), index + 1
        elseif c == "\\" then
            local nextChar = str:sub(index + 1, index + 1)
            if nextChar == '"' or nextChar == "\\" or nextChar == "/" then
                buffer[#buffer + 1] = nextChar
                index = index + 2
            elseif nextChar == "b" then
                buffer[#buffer + 1] = "\b"
                index = index + 2
            elseif nextChar == "f" then
                buffer[#buffer + 1] = "\f"
                index = index + 2
            elseif nextChar == "n" then
                buffer[#buffer + 1] = "\n"
                index = index + 2
            elseif nextChar == "r" then
                buffer[#buffer + 1] = "\r"
                index = index + 2
            elseif nextChar == "t" then
                buffer[#buffer + 1] = "\t"
                index = index + 2
            elseif nextChar == "u" then
                local hex = str:sub(index + 2, index + 5)
                buffer[#buffer + 1] = utf8.char(tonumber(hex, 16))
                index = index + 6
            else
                error("Invalid escape in JSON string")
            end
        else
            buffer[#buffer + 1] = c
            index = index + 1
        end
    end
    error("Unterminated JSON string")
end

local function parseNumber(str, index)
    local start = index
    local len = #str
    while index <= len do
        local c = str:sub(index, index)
        if not c:match("[%d%+%-%e%E%.]") then
            break
        end
        index = index + 1
    end
    local number = tonumber(str:sub(start, index - 1))
    if not number then
        error("Invalid JSON number at position " .. start)
    end
    return number, index
end

local function parseLiteral(str, index, literal, value)
    local endIndex = index + #literal - 1
    if str:sub(index, endIndex) == literal then
        return value, endIndex + 1
    end
    error("Unexpected token while parsing JSON at position " .. index)
end

local function parseValue(str, index)
    index = skipWhitespace(str, index)
    local c = str:sub(index, index)
    if c == '"' then
        return parseString(str, index)
    elseif c == "-" or c:match("%d") then
        return parseNumber(str, index)
    elseif c == "{" then
        local obj = {}
        index = index + 1
        index = skipWhitespace(str, index)
        if str:sub(index, index) == "}" then
            return obj, index + 1
        end
        while true do
            local key
            key, index = parseValue(str, index)
            index = skipWhitespace(str, index)
            if str:sub(index, index) ~= ":" then
                error("Expected ':' in object at position " .. index)
            end
            index = skipWhitespace(str, index + 1)
            local value
            value, index = parseValue(str, index)
            obj[key] = value
            index = skipWhitespace(str, index)
            local char = str:sub(index, index)
            if char == "}" then
                return obj, index + 1
            elseif char ~= "," then
                error("Expected ',' or '}' in object at position " .. index)
            end
            index = skipWhitespace(str, index + 1)
        end
    elseif c == "[" then
        local arr = {}
        index = index + 1
        index = skipWhitespace(str, index)
        if str:sub(index, index) == "]" then
            return arr, index + 1
        end
        local i = 1
        while true do
            arr[i], index = parseValue(str, index)
            i = i + 1
            index = skipWhitespace(str, index)
            local char = str:sub(index, index)
            if char == "]" then
                return arr, index + 1
            elseif char ~= "," then
                error("Expected ',' or ']' in array at position " .. index)
            end
            index = skipWhitespace(str, index + 1)
        end
    elseif c == "t" then
        return parseLiteral(str, index, "true", true)
    elseif c == "f" then
        return parseLiteral(str, index, "false", false)
    elseif c == "n" then
        return parseLiteral(str, index, "null", nil)
    else
        error("Unexpected character while parsing JSON: " .. tostring(c))
    end
end

function json.decode(str)
    local value, index = parseValue(str, 1)
    index = skipWhitespace(str, index)
    if index <= #str then
        error("Trailing characters in JSON data")
    end
    return value
end

return json


