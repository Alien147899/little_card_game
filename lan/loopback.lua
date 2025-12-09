local state = require("core.state")

local loopback = {}

local function deepEqual(a, b)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then
            return false
        end
    end
    for k, _ in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

function loopback.verify(game)
    local snapshot = state.snapshot(game)
    local payload = state.encode(snapshot)
    local decoded = state.decode(payload)
    local equal = deepEqual(snapshot, decoded)
    return equal, {
        payloadSize = #payload,
        cardCount = #(snapshot.deck or {}),
    }
end

return loopback


