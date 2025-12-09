local socket = require("socket")
local json = require("core.json")

local discovery = {}

local BROADCAST_IP = "255.255.255.255"
local DISCOVERY_PORT = 22112

local function closeSocket(sock)
    if sock then
        pcall(function()
            sock:close()
        end)
    end
end

function discovery.startHost(initialInfo)
    if discovery.hostSocket then
        discovery.hostInfo = initialInfo or discovery.hostInfo
        return true
    end
    local udp, err = socket.udp()
    if not udp then
        return false, err
    end
    udp:settimeout(0)
    udp:setoption("broadcast", true)
    discovery.hostSocket = udp
    discovery.hostInfo = initialInfo or {}
    discovery.hostTimer = 0
    return true
end

function discovery.updateHost(info, dt)
    if not discovery.hostSocket then
        return
    end
    discovery.hostInfo = discovery.hostInfo or {}
    if info then
        for k, v in pairs(info) do
            discovery.hostInfo[k] = v
        end
    end
    discovery.hostTimer = (discovery.hostTimer or 0) + (dt or 0)
    if discovery.hostTimer >= 1 then
        discovery.hostTimer = 0
        discovery.hostInfo.timestamp = love.timer.getTime()
        local payload = json.encode({type = "room", data = discovery.hostInfo})
        discovery.hostSocket:sendto(payload, BROADCAST_IP, DISCOVERY_PORT)
    end
end

function discovery.stopHost()
    closeSocket(discovery.hostSocket)
    discovery.hostSocket = nil
    discovery.hostInfo = nil
    discovery.hostTimer = 0
end

function discovery.startClient()
    if discovery.clientSocket then
        return true
    end
    local udp, err = socket.udp()
    if not udp then
        return false, err
    end
    udp:settimeout(0)
    local ok, bindErr = udp:setsockname("*", DISCOVERY_PORT)
    if not ok then
        closeSocket(udp)
        return false, bindErr
    end
    discovery.clientSocket = udp
    return true
end

function discovery.pollClient()
    if not discovery.clientSocket then
        return {}
    end
    local rooms = {}
    while true do
        local data, ip = discovery.clientSocket:receivefrom()
        if not data then
            break
        end
        local ok, decoded = pcall(json.decode, data)
        if ok and decoded and decoded.type == "room" and decoded.data then
            decoded.data.ip = ip
            table.insert(rooms, decoded.data)
        end
    end
    return rooms
end

function discovery.stopClient()
    closeSocket(discovery.clientSocket)
    discovery.clientSocket = nil
end

return discovery


