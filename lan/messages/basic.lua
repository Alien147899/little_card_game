local json = require("core.json")

local messages = {}

function messages.encode(packet)
    return json.encode(packet)
end

function messages.decode(payload)
    return json.decode(payload)
end

function messages.build(typeName, data)
    return {type = typeName, data = data or {}}
end

return messages


