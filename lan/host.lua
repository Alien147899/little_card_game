local enet = require("enet")
local state = require("core.state")
local messages = require("lan.messages.basic")

local host = {}
local messageHandler = nil

local function trySend(peer, packet)
    if not peer or peer:state() ~= "connected" then
        return
    end
    local ok, err = pcall(function()
        peer:send(messages.encode(packet))
    end)
    if not ok then
        print("[Host] Send error:", err)
    end
end

local function dispatch(game, messageType, data, peer)
    if messageHandler then
        messageHandler(game, {type = messageType, data = data or {}, peer = peer})
    end
end

function host.setMessageHandler(handler)
    messageHandler = handler
end

function host.start(game, config)
    host.config = config or {port = 22111}
    local address = ("*:%d"):format(host.config.port)
    local ok, server = pcall(enet.host_create, address)
    if not ok or not server then
        host.running = false
        host.status = "error"
        host.error = "Unable to listen on port " .. tostring(host.config.port)
        return false, host.error
    end
    host.server = server
    host.running = true
    host.lastSnapshot = state.serialize(game)
    host.status = "waiting"
    host.peers = {}
    host.broadcastTimer = 0
    return true
end

function host.stop()
    host.running = false
    host.peers = {}
    host.status = "idle"
    if host.server then
        host.server = nil
    end
end

function host.broadcast(game)
    if not host.server then
        return
    end
    host.lastSnapshot = state.serialize(game)
    local snapshotSize = host.lastSnapshot and #host.lastSnapshot or 0
    print(string.format("[Host] Broadcasting state: snapshotSize=%d bytes, screen=%s, mode=%s, matchActive=%s", 
        snapshotSize, tostring(game.screen), tostring(game.mode), tostring(game.lan and game.lan.matchActive)))
    local payload = messages.build("state", {snapshot = host.lastSnapshot})
    local peerCount = 0
    for peer in pairs(host.peers or {}) do
        trySend(peer, payload)
        peerCount = peerCount + 1
    end
    if peerCount > 0 then
        print(string.format("[Host] Sent state to %d client(s)", peerCount))
    end
end

local function handleReceive(event, game)
    local decoded
    local ok = pcall(function()
        decoded = messages.decode(event.data)
    end)
    if not ok or not decoded then
        return
    end
    
    if decoded.type == "hello" then
        host.status = "player_joined"
        host.peers[event.peer] = true
        trySend(event.peer, messages.build("welcome", {}))
        host.broadcast(game)
        dispatch(game, "hello", decoded.data or {}, event.peer)
    elseif decoded.type == "action" then
        -- Handle actions directly without a queue
        local actionData = decoded.data or {}
        actionData.peer = event.peer
        print(string.format("[Host] Received client action: type=%s", tostring(actionData.type)))
        dispatch(game, "action", actionData, event.peer)
    elseif decoded.type == "state_request" then
        trySend(event.peer, messages.build("state", {snapshot = host.lastSnapshot}))
    end
end

function host.tick(game, dt)
    if not host.running or not host.server then
        return
    end
    
    local event = host.server:service(0)
    while event do
        if event.type == "connect" then
            host.peers[event.peer] = true
            host.status = "player_joined"
            dispatch(game, "connect", nil, event.peer)
        elseif event.type == "disconnect" then
            host.peers[event.peer] = nil
            host.status = "player_left"
            dispatch(game, "disconnect", nil, event.peer)
        elseif event.type == "receive" then
            handleReceive(event, game)
        end
        event = host.server:service(0)
    end
    
    -- Periodically broadcast state (every 0.25 seconds)
    host.broadcastTimer = (host.broadcastTimer or 0) + dt
    if host.broadcastTimer >= 0.25 then
        host.broadcastTimer = 0
        host.broadcast(game)
    end
end

return host
