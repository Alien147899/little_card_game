local lan_mode = {}
local host = require("lan.host")
local client = require("lan.client")
local loopback = require("lan.loopback")
local discovery = require("lan.discovery")
local local_mode = require("modes.local_mode")
local game_logic = require("game_logic")
local perspective = require("lan.perspective")
local turn = require("lan.turn")
local roles = require("lan.roles")

local ROOM_ID_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

local function localPlayerName(game)
    if game.profile and game.profile.getName then
        return game.profile.getName()
    end
    return "Player"
end

local function randomRoomId()
    local chars = {}
    for i = 1, 4 do
        local idx = math.random(#ROOM_ID_CHARS)
        table.insert(chars, ROOM_ID_CHARS:sub(idx, idx))
    end
    return table.concat(chars)
end

local function resetDiscoveryLists(game)
    game.lan.roomsById = {}
    game.lan.availableRooms = {}
end

local function ensureLanState(game)
    game.lan = game.lan or {}
    local lan = game.lan
    lan.status = lan.status or "idle"
    lan.message = lan.message or "Please choose to create or join a room"
    lan.view = lan.view or "menu"
    lan.roomId = lan.roomId or randomRoomId()
    lan.players = lan.players or {}
    lan.players.host = lan.players.host or { name = localPlayerName(game), ready = false, isHost = true }
    lan.players.guest = lan.players.guest
    lan.matchActive = lan.matchActive or false
    resetDiscoveryLists(game)
end

local function resetToMenu(game)
    ensureLanState(game)
    discovery.stopClient()
    if game.lan.role == "host" and game.lan.host then
        host.stop()
        discovery.stopHost()
    elseif game.lan.role == "client" and game.lan.client then
        client.disconnect()
    end
    game.lan.status = "idle"
    game.lan.message = "Please choose to create or join a room"
    game.lan.role = nil
    game.lan.view = "menu"
    game.lan.matchActive = false
    game.lan.players.host = { name = localPlayerName(game), ready = false, isHost = true }
    game.lan.players.guest = nil
    resetDiscoveryLists(game)
end

local function playerCount(game)
    local count = 0
    if game.lan.players.host then
        count = count + 1
    end
    if game.lan.players.guest then
        count = count + 1
    end
    return count
end

local function updateReadyStatus(game)
    local hostReady = game.lan.players.host and game.lan.players.host.ready
    local guestReady = game.lan.players.guest and game.lan.players.guest.ready
    game.lan.allReady = hostReady and guestReady
    print(string.format("[UpdateReadyStatus] host.ready=%s, guest.ready=%s, allReady=%s",
        tostring(hostReady), tostring(guestReady), tostring(game.lan.allReady)))
    if game.lan.allReady then
        game.lan.message = "Both players are ready; host can start the match"
    end
end

local function updatePlayersSelfFlag(game)
    if not game.lan.players then
        return
    end
    if game.lan.role == "host" then
        if game.lan.players.host then
            game.lan.players.host.isSelf = true
        end
        if game.lan.players.guest then
            game.lan.players.guest.isSelf = false
        end
    elseif game.lan.role == "client" then
        if game.lan.players.host then
            game.lan.players.host.isSelf = false
        end
        if game.lan.players.guest then
            game.lan.players.guest.isSelf = true
        end
    else
        if game.lan.players.host then
            game.lan.players.host.isSelf = false
        end
        if game.lan.players.guest then
            game.lan.players.guest.isSelf = false
        end
    end
end

local function mergeDiscoveredRooms(game, newEntries)
    game.lan.roomsById = game.lan.roomsById or {}
    local now = love.timer.getTime()
    if newEntries then
        for _, entry in ipairs(newEntries) do
            if entry.roomId then
                entry.lastSeen = now
                entry.capacity = entry.capacity or 2
                entry.players = entry.players or 1
                local key = entry.roomId .. "@" .. entry.ip
                game.lan.roomsById[key] = entry
            end
        end
    end
    for key, room in pairs(game.lan.roomsById) do
        if now - (room.lastSeen or now) > 5 then
            game.lan.roomsById[key] = nil
        end
    end
    game.lan.availableRooms = {}
    for _, room in pairs(game.lan.roomsById) do
        table.insert(game.lan.availableRooms, room)
    end
    table.sort(game.lan.availableRooms, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
end

local function updateDiscovery(game, dt)
    if game.lan.role == "host" and game.lan.host then
        discovery.startHost({
            roomId = game.lan.roomId,
            name = localPlayerName(game),
            port = game.lan.hostConfig and game.lan.hostConfig.port or 22111,
        })
        discovery.updateHost({
            status = game.lan.matchActive and "in_game" or "waiting",
            players = playerCount(game),
            capacity = 2,
        }, dt)
    elseif game.lan.discoveryListening then
        mergeDiscoveredRooms(game, discovery.pollClient())
        mergeDiscoveredRooms(game, nil)
    end
end

function lan_mode.sync(game)
    if game.lan.role == "host" and game.lan.host then
        host.broadcast(game)
    end
end

function lan_mode.enter(game)
    ensureLanState(game)
    game.mode = "lan"
    game.screen = "lan"
    game.state = "lan_menu"
    resetToMenu(game)
end

function lan_mode.backToMenu(game)
    resetToMenu(game)
    game.mode = "local"
    game.screen = "menu"
end

function lan_mode.startHost(game, config)
    ensureLanState(game)
    game.lan.role = "host"
    game.lan.hostConfig = config or { port = 22111 }
    local ok, err = host.start(game, game.lan.hostConfig)
    if not ok then
        game.lan.status = "error"
        game.lan.message = err or "Unable to start host"
        return
    end
    host.setMessageHandler(function(g, message)
        lan_mode.handleHostMessage(g, message)
    end)
    game.lan.host = host
    game.lan.status = "hosting"
    game.lan.message = string.format("Listening on local port %d, waiting for players to join", game.lan.hostConfig.port)
    discovery.startHost({
        roomId = game.lan.roomId,
        name = localPlayerName(game),
        port = game.lan.hostConfig.port,
    })
end

function lan_mode.startClient(game, config)
    ensureLanState(game)
    game.lan.role = "client"
    game.lan.clientConfig = config or { host = "127.0.0.1", port = 22111 }
    local ok, err = client.connect(game, game.lan.clientConfig)
    if not ok then
        game.lan.status = "error"
        game.lan.message = err or "Unable to connect to host"
        return
    end
    discovery.stopClient()
    game.lan.discoveryListening = false
    game.lan.client = client
    game.lan.status = "connecting"
    game.lan.message = string.format("Connecting to %s:%d ...", game.lan.clientConfig.host, game.lan.clientConfig.port)
end

function lan_mode.update(game, dt)
    if not game.lan then
        return
    end
    if game.lan.role == "host" and game.lan.host then
        host.tick(game, dt)
    elseif game.lan.role == "client" and game.lan.client then
        client.tick(game, dt)
    end
    updateDiscovery(game, dt)
    updatePlayersSelfFlag(game)
end

function lan_mode.startHostLobby(game)
    ensureLanState(game)
    game.lan.role = "host"
    game.lan.view = "host"
    game.lan.players.host = { name = localPlayerName(game), ready = false, isSelf = true, isHost = true }
    game.lan.players.guest = nil
    if not game.lan.host then
        lan_mode.startHost(game)
    end
    game.lan.message = "Waiting for other players to join..."
end

function lan_mode.openJoinList(game)
    ensureLanState(game)
    local ok, err = discovery.startClient()
    if not ok then
        game.lan.message = "Unable to start room discovery: " .. tostring(err)
        return
    end
    game.lan.discoveryListening = true
    resetDiscoveryLists(game)
    game.lan.view = "join"
    game.lan.message = "Searching for rooms..."
end

function lan_mode.connectToRoom(game, room)
    ensureLanState(game)
    if not room or not room.ip then
        game.lan.message = "Unable to join this room"
        return
    end
    lan_mode.startClient(game, { host = room.ip, port = room.port })
    game.lan.players.host = { name = room.name or "Host", ready = false, isHost = true }
    game.lan.players.guest = { name = localPlayerName(game), ready = false, isSelf = true }
    game.lan.view = "host"
    game.lan.message = string.format("Connecting to room %s ...", room.roomId or "")
end

local function isValidIP(ip)
    if not ip or ip == "" then
        return false
    end
    ip = ip:gsub("%s+", "") -- Remove whitespace
    if ip == "" then
        return false
    end
    -- Only allow digits, dots and colon
    if not ip:match("^[%d%.%:]+$") then
        return false
    end
    -- Simple IPv4 format check: x.x.x.x
    local parts = {}
    for part in ip:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    if #parts ~= 4 then
        return false
    end
    -- Check each part is 0–255
    for _, part in ipairs(parts) do
        local num = tonumber(part)
        if not num or num < 0 or num > 255 then
            return false
        end
    end
    return true
end

function lan_mode.connectByIP(game, ip)
    ensureLanState(game)
    if not ip or ip == "" then
        game.lan.message = "Please enter a valid IP address"
        return false
    end
    -- Trim whitespace
    ip = ip:gsub("^%s+", ""):gsub("%s+$", "")
    if ip == "" then
        game.lan.message = "Please enter a valid IP address"
        return false
    end
    -- Validate IP format
    if not isValidIP(ip) then
        game.lan.message = "Invalid IP format, expected something like 192.168.1.100"
        return false
    end
    local port = 22111
    lan_mode.startClient(game, { host = ip, port = port })
    game.lan.players.host = { name = "Host", ready = false, isHost = true }
    game.lan.players.guest = { name = localPlayerName(game), ready = false, isSelf = true }
    game.lan.view = "host"
    game.lan.message = string.format("Connecting to %s:%d ...", ip, port)
    return true
end

function lan_mode.toggleReady(game)
    ensureLanState(game)
    if game.lan.role == "host" then
        local hostPlayer = game.lan.players.host
        if not hostPlayer then
            hostPlayer = { name = localPlayerName(game), ready = false, isSelf = true, isHost = true }
            game.lan.players.host = hostPlayer
        end
        hostPlayer.ready = not hostPlayer.ready
        game.lan.message = hostPlayer.ready and "Host is ready" or "Host cancelled ready"
        updateReadyStatus(game)
        lan_mode.sync(game)
    elseif game.lan.role == "client" then
        -- Client does not update local ready flag; it sends a request to host and waits for synced state
        game.lan.message = "Switching ready state..."
        print("[Client] Sending ready_toggle request to host")
        client.sendAction({ type = "ready_toggle" })
    end
end

local function beginMatch(game)
    -- Initialize game state but preserve LAN-specific settings
    local card_module = require("card")
    local utils = require("utils")
    local config = require("config")
    
    -- Save LAN-related state
    local lanState = {
        role = game.lan.role,
        matchActive = true,
        players = game.lan.players,
        allReady = game.lan.allReady,
    }
    
    -- Initialize game state (similar to local_mode.start, but do not overwrite mode)
    game.state = "await_start"
    game.message = "Click \"Start New Round\" to draw cards and decide the banker"
    game.humanRole = "idle"
    game.humanMatchWins = 0
    game.aiMatchWins = 0
    game.playerLives = config.GAME.initialLives
    game.dealerLives = config.GAME.initialLives
    game.matchWinner = nil
    game.rolesDecided = false
    game.roleDraw = nil
    game.revealDealer = false
    game.nextOpponentDealDelay = 0
    game.dealerInitialCount = 0
    game.dealerPeekLog = {}
    game.aiRoundMood = 0
    game.aiConfidence = 0
    game.aiMemory = {
        idleCardSamples = 0,
        idleCardTotal = 0,
        bankerCardSamples = 0,
        bankerCardTotal = 0,
    }
    game.deck = card_module.buildDeck()
    utils.shuffle(game.deck)
    game.playerHand = {}
    game.opponentHand = {}
    game.boardCards = {}
    game.draggedCard = nil
    game.highlightedCard = nil
    
    -- LAN-specific fields
    game.currentPlayer = nil
    game.hostLives = config.GAME.initialLives
    game.guestLives = config.GAME.initialLives
    game.hostMatchWins = 0
    game.guestMatchWins = 0
    game.hostRole = nil
    game.guestRole = nil
    game.hostHand = {}
    game.guestHand = {}
    
    -- Switch to game table screen
    game.screen = "table"
    game.mode = "lan_game"
    game.lan.matchActive = true
    
    roles.initialize(game)
    
    local ui = require("ui")
    local table_scene = require("scenes.table")
    game.zones = ui.buildZones(game)
    table_scene.initializeButtons(game)
    ui.buildButtons(game)
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    ui.layoutBoard(game.boardCards, game.zones.playArea)
    
    game.lan.players = lanState.players
    game.lan.allReady = lanState.allReady
    game.lan.role = lanState.role
    
    print(string.format("[StartMatch] beginMatch complete, screen=%s, mode=%s", game.screen, game.mode))
end

function lan_mode.handleHostMessage(game, message)
    ensureLanState(game)
    if message.type == "hello" then
        local name = (message.data and message.data.name) or "Opponent"
        -- Only create client player if it does not exist to avoid overwriting ready state
        if not game.lan.players.guest then
            game.lan.players.guest = { name = name, ready = false }
            game.lan.message = name .. " joined the room"
            print("[Host] New client joined: " .. name)
        else
            -- If guest already exists, only update name
            game.lan.players.guest.name = name
            print("[Host] Client reconnected: " .. name)
        end
        updateReadyStatus(game)
        lan_mode.sync(game)
    elseif message.type == "disconnect" then
        game.lan.players.guest = nil
        game.lan.allReady = false
        game.lan.matchActive = false
        game.lan.message = "Opponent left the room"
        lan_mode.sync(game)
    elseif message.type == "action" then
        print("[Host] Received client action: " .. tostring(message.data and message.data.type))
        lan_mode.processRemoteAction(game, message.data or {})
    end
end

function lan_mode.processRemoteAction(game, payload)
    if not payload or not payload.type then
        print("[Host] processRemoteAction: invalid payload")
        return
    end
    
    local actionType = payload.type
    print(string.format("[Host] Handling client action: %s", actionType))
    
    if actionType == "ready_toggle" then
        -- Ensure guest player exists
        if not game.lan.players.guest then
            game.lan.players.guest = { name = "Opponent", ready = false }
            print("[Host] Created client player object")
        end
        
        -- Toggle ready state
        local oldReady = game.lan.players.guest.ready
        game.lan.players.guest.ready = not oldReady
        local newReady = game.lan.players.guest.ready
        
        print(string.format("[Host] Client ready state: %s -> %s", tostring(oldReady), tostring(newReady)))
        
        -- Update message
        game.lan.message = newReady and "Opponent is ready" or "Opponent cancelled ready"
        
        -- Update overall ready state
        updateReadyStatus(game)
        
        -- Immediately sync state to update client UI
        print("[Host] Syncing state to client...")
        lan_mode.sync(game)
        
    elseif actionType == "role_draw_flip" then
        -- Opponent flips role-draw card
        if game.roleDraw and game.roleDraw.stage == "await_players" then
            game.roleDraw.opponentRevealed = true
            if game.roleDraw.opponentCard then
                -- Start flip animation
                game.roleDraw.opponentCard.isFlipping = true
                game.roleDraw.opponentCard.flipElapsed = 0
                game.roleDraw.opponentCard.flipDuration = 0.45
                game.roleDraw.opponentCard.flipTargetFaceDown = false
                game.roleDraw.opponentCard.flipSwapped = false
            end
            game.message = "Opponent has revealed their role-draw card..."
            lan_mode.sync(game)
        end
    elseif actionType == "hit" or actionType == "stand" or actionType == "start_round" then
        -- Gameplay actions: execute remote actions
        local ui = require("ui")
        if actionType == "hit" then
            game_logic.playerHit(game, ui)
        elseif actionType == "stand" then
            game_logic.playerStand(game, ui)
        elseif actionType == "start_round" then
            game_logic.startRound(game, ui)
        end
        lan_mode.sync(game)
    else
        print(string.format("[Host] Unknown action type: %s", actionType))
    end
end

function lan_mode.handleGameplayAction(game, action, ui)
    local handlers = {
        start_round = function() game_logic.startRound(game, ui) end,
        hit = function() game_logic.playerHit(game, ui) end,
        stand = function() game_logic.playerStand(game, ui) end,
    }
    if not handlers[action] then
        return
    end
    if not (game.lan and game.lan.matchActive) then
        handlers[action]()
        return
    end
    if game.lan.role == "host" then
        handlers[action]()
        lan_mode.sync(game)
    else
        client.sendAction({ type = action })
    end
end

function lan_mode.leaveLobby(game)
    resetToMenu(game)
end

function lan_mode.runLoopbackTest(game)
    ensureLanState(game)
    local ok, info = loopback.verify(game)
    if ok then
        game.lan.message = string.format("Loopback check passed, snapshot size: %d bytes", info.payloadSize)
    else
        game.lan.message = "Loopback check failed (data mismatch); see logs for details"
    end
end

return lan_mode

