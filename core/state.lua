local state = {}
local utils = require("utils")
local json = require("core.json")

local simpleFields = {
    "mode",
    "screen",
    "state",
    "message",
    "humanRole",
    "playerLives",
    "dealerLives",
    "matchWinner",
    "rolesDecided",
    "revealDealer",
    "nextOpponentDealDelay",
    "dealerInitialCount",
    "aiRoundMood",
    "aiConfidence",
    -- Fields used only in LAN mode
    "currentPlayer",      -- Currently active network player ("host"/"client")
    "hostLives",          -- Host lives
    "guestLives",         -- Client lives
    "hostMatchWins",      -- Host match win count
    "guestMatchWins",     -- Client match win count
    "hostRole",           -- Host game role ("banker"/"idle") - reserved
    "guestRole",          -- Client game role - reserved
}

local tableFields = {
    "dealerPeekLog",
    "aiMemory",
}

local cardKeys = {
    "id",
    "label",
    "suit",
    "rank",
    "value",
    "color",
    "textColor",
    "owner",
    "container",
    "faceDown",
    "draggable",
    "x",
    "y",
    "targetX",
    "targetY",
    "moveDelay",
}

local function copyColor(color)
    if not color then
        return nil
    end
    return {color[1], color[2], color[3], color[4]}
end

local function cloneCard(card)
    local data = {}
    for _, key in ipairs(cardKeys) do
        local value = card[key]
        if key == "color" or key == "textColor" then
            data[key] = copyColor(value)
        else
            data[key] = value
        end
    end
    return data
end

local function restoreCard(data)
    local card = {}
    for _, key in ipairs(cardKeys) do
        local value = data and data[key]
        if key == "color" or key == "textColor" then
            card[key] = copyColor(value)
        else
            card[key] = value
        end
    end
    return card
end

local function cloneCardList(list)
    local out = {}
    for i, card in ipairs(list or {}) do
        out[i] = cloneCard(card)
    end
    return out
end

local function restoreCardList(data)
    local out = {}
    for i, cardData in ipairs(data or {}) do
        out[i] = restoreCard(cardData)
    end
    return out
end

local function copyTable(tbl)
    if not tbl then
        return nil
    end
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            result[k] = copyTable(v)
        else
            result[k] = v
        end
    end
    return result
end

function state.snapshot(game)
    local snap = {
        version = 1,
        deck = cloneCardList(game.deck),
        playerHand = cloneCardList(game.playerHand),
        opponentHand = cloneCardList(game.opponentHand),
        boardCards = cloneCardList(game.boardCards),
        roleDraw = nil,  -- Special handling
        clearAnimation = nil,
    }
    
    -- Special handling for roleDraw (contains card objects)
    if game.roleDraw then
        snap.roleDraw = copyTable(game.roleDraw)
        if game.roleDraw.cards then
            snap.roleDraw.cards = cloneCardList(game.roleDraw.cards)
        end
        if game.roleDraw.myCard then
            snap.roleDraw.myCard = cloneCard(game.roleDraw.myCard)
        end
        if game.roleDraw.opponentCard then
            snap.roleDraw.opponentCard = cloneCard(game.roleDraw.opponentCard)
        end
        if game.roleDraw.humanCard then
            snap.roleDraw.humanCard = cloneCard(game.roleDraw.humanCard)
        end
        if game.roleDraw.aiCard then
            snap.roleDraw.aiCard = cloneCard(game.roleDraw.aiCard)
        end
    end
    
    -- In LAN mode: sync host and client hands
    if game.mode == "lan_game" and game.lan and game.lan.matchActive then
        snap.hostHand = cloneCardList(game.hostHand or game.playerHand)
        snap.guestHand = cloneCardList(game.guestHand or game.opponentHand)
    end
    
    for _, key in ipairs(simpleFields) do
        snap[key] = game[key]
    end
    for _, key in ipairs(tableFields) do
        snap[key] = copyTable(game[key])
    end
    -- Sync LAN player state (including ready status)
    if game.lan and game.lan.players then
        snap.lanPlayers = {
            host = game.lan.players.host and copyTable(game.lan.players.host) or nil,
            guest = game.lan.players.guest and copyTable(game.lan.players.guest) or nil,
        }
        snap.allReady = game.lan.allReady
        snap.lanMessage = game.lan.message  -- Sync message text
        snap.matchActive = game.lan.matchActive  -- Sync whether the match has started
    end
    return snap
end

function state.applySnapshot(game, snapshot, hooks)
    hooks = hooks or {}
    if not snapshot then
        return
    end
    
    -- Debug: record previous mode/screen
    local oldMode = game.mode
    local oldScreen = game.screen
    
    for _, key in ipairs(simpleFields) do
        if snapshot[key] ~= nil then
            game[key] = snapshot[key]
        end
    end
    
    -- Debug: if mode or screen changed, log details
    if game.lan and game.lan.role == "client" then
        print(string.format("[Client] ===== Receiving state update ====="))
        print(string.format("[Client] Before: mode=%s, screen=%s, matchActive=%s", 
            tostring(oldMode), tostring(oldScreen), tostring(game.lan.matchActive)))
        print(string.format("[Client] In snapshot: mode=%s, screen=%s, matchActive=%s", 
            tostring(snapshot.mode), tostring(snapshot.screen), tostring(snapshot.matchActive)))
        
        if oldMode ~= game.mode then
            print(string.format("[Client] *** Mode changed: %s -> %s ***", tostring(oldMode), tostring(game.mode)))
        end
        if oldScreen ~= game.screen then
            print(string.format("[Client] *** Screen changed: %s -> %s ***", tostring(oldScreen), tostring(game.screen)))
            -- If switched to table view, initialize UI
            if game.screen == "table" then
                print("[Client] *** Switched to table screen, initializing UI ***")
                local ui = require("ui")
                local table_scene = require("scenes.table")
                game.zones = ui.buildZones(game)
                table_scene.initializeButtons(game)
                ui.buildButtons(game)  -- Set button positions and sizes
                -- Layout hands
                ui.layoutHand(game.playerHand, game.zones.playerHand, game)
                ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
                ui.layoutBoard(game.boardCards, game.zones.playArea)
                print(string.format("[Client] *** UI initialized, current screen=%s, zones=%s, buttons=%s ***", 
                    tostring(game.screen), tostring(game.zones ~= nil), tostring(game.buttons ~= nil)))
            end
        else
            print(string.format("[Client] Screen unchanged, current screen=%s", tostring(game.screen)))
            -- Even if screen is unchanged, ensure UI is initialized when in table and matchActive
            if game.screen == "table" and snapshot.matchActive and (not game.zones or not game.buttons) then
                print("[Client] *** Screen is table but UI not initialized; initializing now ***")
                local ui = require("ui")
                local table_scene = require("scenes.table")
                if not game.zones then
                    game.zones = ui.buildZones(game)
                end
                if not game.buttons then
                    table_scene.initializeButtons(game)
                    ui.buildButtons(game)  -- Set button positions and sizes
                end
                ui.layoutHand(game.playerHand, game.zones.playerHand, game)
                ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
                ui.layoutBoard(game.boardCards, game.zones.playArea)
                print("[Client] UI initialization complete")
            end
        end
        print(string.format("[Client] After: mode=%s, screen=%s, matchActive=%s", 
            tostring(game.mode), tostring(game.screen), tostring(game.lan.matchActive)))
        print(string.format("[Client] ===== State update complete =====\n"))
    end
    for _, key in ipairs(tableFields) do
        if snapshot[key] ~= nil then
            game[key] = copyTable(snapshot[key])
        end
    end
    game.deck = restoreCardList(snapshot.deck)
    game.playerHand = restoreCardList(snapshot.playerHand)
    game.opponentHand = restoreCardList(snapshot.opponentHand)
    game.boardCards = restoreCardList(snapshot.boardCards)
    
    -- Special handling for roleDraw (restore card objects)
    if snapshot.roleDraw then
        if game.lan and game.lan.role == "client" then
            print(string.format("[Client] Received roleDraw: stage=%s, cards=%d", 
                tostring(snapshot.roleDraw.stage), 
                snapshot.roleDraw.cards and #snapshot.roleDraw.cards or 0))
        end
        
        game.roleDraw = copyTable(snapshot.roleDraw)
        if snapshot.roleDraw.cards then
            game.roleDraw.cards = restoreCardList(snapshot.roleDraw.cards)
        end
        if snapshot.roleDraw.myCard then
            game.roleDraw.myCard = restoreCard(snapshot.roleDraw.myCard)
        end
        if snapshot.roleDraw.opponentCard then
            game.roleDraw.opponentCard = restoreCard(snapshot.roleDraw.opponentCard)
        end
        if snapshot.roleDraw.humanCard then
            game.roleDraw.humanCard = restoreCard(snapshot.roleDraw.humanCard)
        end
        if snapshot.roleDraw.aiCard then
            game.roleDraw.aiCard = restoreCard(snapshot.roleDraw.aiCard)
        end
        
        if game.lan and game.lan.role == "client" then
            print(string.format("[Client] roleDraw restore complete: stage=%s, myCard=%s, opponentCard=%s", 
                tostring(game.roleDraw.stage),
                game.roleDraw.myCard and game.roleDraw.myCard.label or "nil",
                game.roleDraw.opponentCard and game.roleDraw.opponentCard.label or "nil"))
        end
    else
        game.roleDraw = nil
    end
    
    -- In LAN mode: restore host and client hands
    if snapshot.hostHand then
        game.hostHand = restoreCardList(snapshot.hostHand)
    end
    if snapshot.guestHand then
        game.guestHand = restoreCardList(snapshot.guestHand)
    end
    
    game.clearAnimation = nil
    game.draggedCard = nil
    game.highlightedCard = nil
    
    -- Apply LAN player state (preserving local isSelf flags)
    if snapshot.lanPlayers and game.lan then
        game.lan.players = game.lan.players or {}
        
        -- Save old ready state values for comparison
        local oldHostReady = game.lan.players.host and game.lan.players.host.ready
        local oldGuestReady = game.lan.players.guest and game.lan.players.guest.ready
        
        -- Update host ready/player state
        if snapshot.lanPlayers.host then
            local localIsSelf = game.lan.players.host and game.lan.players.host.isSelf
            game.lan.players.host = copyTable(snapshot.lanPlayers.host)
            if game.lan.role == "host" and localIsSelf then
                game.lan.players.host.isSelf = true
            end
        end
        
        -- Update client ready/player state
        if snapshot.lanPlayers.guest then
            local localIsSelf = game.lan.players.guest and game.lan.players.guest.isSelf
            game.lan.players.guest = copyTable(snapshot.lanPlayers.guest)
            if game.lan.role == "client" then
                if localIsSelf then
                    game.lan.players.guest.isSelf = true
                end
            end
        end
        
        -- When client receives state updates, adjust displayed messages
        if game.lan.role == "client" then
            local newHostReady = game.lan.players.host and game.lan.players.host.ready
            local newGuestReady = game.lan.players.guest and game.lan.players.guest.ready
            
            -- Debug logs for ready state changes
            if oldHostReady ~= newHostReady then
                print(string.format("[Client] Host ready state: %s -> %s", tostring(oldHostReady), tostring(newHostReady)))
            end
            if oldGuestReady ~= newGuestReady then
                print(string.format("[Client] Self ready state: %s -> %s", tostring(oldGuestReady), tostring(newGuestReady)))
            end
            
            -- Update messages (priority: self change > host change > waiting)
            local needUpdateMessage = false
            if game.lan.message == "Switching ready state..." then
                -- Force update of waiting status
                needUpdateMessage = true
                if newGuestReady then
                    game.lan.message = "You are ready"
                else
                    game.lan.message = "Waiting for other players..."
                end
                print("[Client] Updated waiting message")
            elseif oldGuestReady ~= newGuestReady then
                -- Local player's ready state changed
                needUpdateMessage = true
                game.lan.message = newGuestReady and "You are ready" or "You cancelled ready"
            elseif oldHostReady ~= newHostReady then
                -- Host ready state changed
                needUpdateMessage = true
                game.lan.message = newHostReady and "Host is ready" or "Host cancelled ready"
            end
        end
        
        -- Update allReady flag
        if snapshot.allReady ~= nil then
            game.lan.allReady = snapshot.allReady
        end
        
        -- Update matchActive flag
        if snapshot.matchActive ~= nil then
            local oldMatchActive = game.lan.matchActive
            game.lan.matchActive = snapshot.matchActive
            
            -- Client detects game start
            if game.lan.role == "client" then
                if not oldMatchActive and game.lan.matchActive then
                    print("[Client] Game started! matchActive: false -> true, screen=" .. tostring(game.screen))
                    -- Force switch to table view regardless of snapshot screen
                    if game.screen ~= "table" then
                        print("[Client] Warning: screen is not table, forcing table")
                        game.screen = "table"
                    end
                elseif game.lan.matchActive and game.screen ~= "table" then
                    -- Even if matchActive is already true, force table if screen differs
                    print("[Client] Warning: matchActive=true but screen is not table, forcing table")
                    game.screen = "table"
                end
                
                -- When matchActive=true and screen=table, ensure UI is initialized
                if game.lan.matchActive and game.screen == "table" then
                    if not game.zones or not game.buttons then
                        print("[Client] matchActive=true and screen=table, UI not initialized; initializing...")
                        local ui = require("ui")
                        local table_scene = require("scenes.table")
                        if not game.zones then
                            game.zones = ui.buildZones(game)
                        end
                        if not game.buttons then
                            table_scene.initializeButtons(game)
                            ui.buildButtons(game)  -- Set button positions and sizes
                        end
                        -- Layout hands
                        ui.layoutHand(game.playerHand, game.zones.playerHand, game)
                        ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
                        ui.layoutBoard(game.boardCards, game.zones.playArea)
                        print("[Client] UI ready; game can start. Current screen=" .. tostring(game.screen))
                    end
                end
            end
        end
        
        -- When host receives state, sync LAN message (but do not overwrite client's local feedback)
        if snapshot.lanMessage and game.lan.role == "host" then
            game.lan.message = snapshot.lanMessage
        end
    end
    
    if hooks.afterApply then
        hooks.afterApply(game, snapshot)
    end
end

function state.encode(snapshot)
    return json.encode(snapshot)
end

function state.decode(payload)
    return json.decode(payload)
end

function state.serialize(game)
    return state.encode(state.snapshot(game))
end

function state.deserialize(game, payload, hooks)
    local decoded = state.decode(payload)
    state.applySnapshot(game, decoded, hooks)
end

return state


