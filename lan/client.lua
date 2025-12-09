local enet = require("enet")
local state = require("core.state")
local messages = require("lan.messages.basic")

local client = {}

local function send(packet)
    if client.serverPeer and client.serverPeer:state() == "connected" then
        local ok, err = pcall(function()
            client.serverPeer:send(messages.encode(packet))
        end)
        if not ok then
            print("[Client] Send error:", err)
        end
    else
        print("[Client] Cannot send: not connected")
    end
end

function client.connect(game, config)
    client.config = config or {host = "127.0.0.1", port = 22111}
    local ok, hostHandle = pcall(enet.host_create)
    if not ok or not hostHandle then
        client.status = "error"
        client.connected = false
        client.error = "Unable to create ENet client"
        return false, client.error
    end
    client.host = hostHandle
    local address = ("%s:%d"):format(client.config.host, client.config.port)
    local peer = client.host:connect(address)
    client.serverPeer = peer
    client.connected = false
    client.status = "connecting"
    print(string.format("[Client] Connecting to %s:%d", client.config.host, client.config.port))
    return true
end

function client.disconnect()
    if client.serverPeer then
        client.serverPeer:disconnect()
        client.serverPeer = nil
    end
    if client.host then
        client.host = nil
    end
    client.connected = false
    client.status = "idle"
    print("[Client] Disconnected")
end

local function applyState(snapshot, game)
    if not snapshot then
        print("[Client] Warning: applyState received nil snapshot")
        return
    end
    -- Snapshot should be a JSON string; deserialize will decode it
    print(string.format("[Client] applyState: snapshot type=%s, length=%s", type(snapshot), type(snapshot) == "string" and #snapshot or "N/A"))
    state.deserialize(game, snapshot)
end

local function handleReceive(event, game)
    local decoded
    local ok = pcall(function()
        decoded = messages.decode(event.data)
    end)
    if not ok or not decoded then
        print("[Client] Failed to decode message")
        return
    end
    
    if decoded.type == "welcome" then
        client.status = "in_game"
        client.connected = true
        print("[Client] Received welcome message, requesting state")
        send(messages.build("state_request", {}))
    elseif decoded.type == "state" then
        print("[Client] ========== Received state update ==========")
        local snapshot = decoded.data and decoded.data.snapshot
        if snapshot then
            print(string.format("[Client] Snapshot type: %s", type(snapshot)))
            if type(snapshot) == "string" then
                print(string.format("[Client] Snapshot is JSON string, length=%d", #snapshot))
                -- Try decoding to inspect contents
                local json = require("core.json")
                local decoded_snapshot = json.decode(snapshot)
                if decoded_snapshot then
                    print(string.format("[Client] Decoded snapshot: mode=%s, screen=%s, matchActive=%s", 
                        tostring(decoded_snapshot.mode), tostring(decoded_snapshot.screen), tostring(decoded_snapshot.matchActive)))
                end
            end
            print(string.format("[Client] Current state: mode=%s, screen=%s, matchActive=%s", 
                tostring(game.mode), tostring(game.screen), tostring(game.lan and game.lan.matchActive)))
        else
            print("[Client] Warning: snapshot is empty!")
        end
        applyState(snapshot, game)
        client.connected = true
        client.status = "in_game"
        print(string.format("[Client] After applying state: mode=%s, screen=%s, matchActive=%s", 
            tostring(game.mode), tostring(game.screen), tostring(game.lan and game.lan.matchActive)))
        print("[Client] ========== State update complete ==========\n")
    elseif decoded.type == "error" then
        client.status = "error"
        client.message = decoded.data and decoded.data.message
        print("[Client] Received error:", client.message)
    end
end

function client.sendAction(action)
    print(string.format("[Client] Sending action: type=%s", tostring(action and action.type)))
    send(messages.build("action", action or {}))
end

function client.tick(game, dt)
    if not client.host then
        return
    end
    local event = client.host:service(0)
    while event do
        if event.type == "connect" then
            client.status = "connected"
            print("[Client] Connected to server")
            send(messages.build("hello", {name = (game.profile and game.profile.getName()) or "Player"}))
        elseif event.type == "disconnect" then
            client.status = "disconnected"
            client.connected = false
            print("[Client] Disconnected from server")
        elseif event.type == "receive" then
            handleReceive(event, game)
        end
        event = client.host:service(0)
    end
end

return client
