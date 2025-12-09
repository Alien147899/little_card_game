-- Turn control module
-- Manages turn order and permissions in LAN mode
local turn = {}

local perspective = require("lan.perspective")

-- Check whether the game is in LAN mode
local function isLanMode(game)
    return game.mode == "lan_game" and game.lan and game.lan.matchActive
end

-- Start a turn for a given network player
-- @param player: "host" or "client"
function turn.startTurn(game, player)
    if not isLanMode(game) then
        return
    end
    
    game.currentPlayer = player
    
    -- Update message for both sides
    if game.lan.role == player then
        game.message = "It is your turn"
    else
        local playerName = (player == "host") and "Host" or "Opponent"
        game.message = "Waiting for " .. playerName .. " to act..."
    end
    
    print(string.format("[Turn] Turn start: %s", player))
end

-- End the current turn
function turn.endTurn(game)
    if not isLanMode(game) then
        return
    end
    
    -- Do not immediately switch turn; wait for game logic to decide
    game.currentPlayer = nil
    print("[Turn] Turn end")
end

-- Switch turn to the opponent
function turn.switchToOpponent(game)
    if not isLanMode(game) then
        return
    end
    
    local current = game.currentPlayer or game.lan.role
    local next = (current == "host") and "client" or "host"
    turn.startTurn(game, next)
end

-- Whether the local player may act this frame
function turn.canOperate(game)
    if not isLanMode(game) then
        return true  -- Local mode: the human can always act
    end
    
    return perspective.isMyTurn(game)
end

-- Set state to "waiting for opponent" with a human-readable action
function turn.waitForOpponent(game, action)
    if not isLanMode(game) then
        return
    end
    
    local actionText = action or "action"
    game.message = "Waiting for opponent " .. actionText .. "..."
    game.currentPlayer = perspective.getOpponentNetworkRole(game)
    
    print(string.format("[Turn] Waiting for opponent: %s", actionText))
end

-- Role-draw phase: start
function turn.startRoleDetermination(game)
    if not isLanMode(game) then
        return
    end
    
    -- During role-draw, both sides can act (each flips their own card)
    game.currentPlayer = nil  -- Do not restrict action to a specific player
    game.message = "Please click your role-draw card to reveal it"
    
    print("[Turn] Enter role-draw phase")
end

-- Role-draw phase: wait for opponent to reveal
function turn.waitForOpponentFlip(game)
    if not isLanMode(game) then
        return
    end
    
    game.message = "Waiting for opponent to reveal their role-draw card..."
    print("[Turn] Waiting for opponent to flip")
end

-- Banker draw phase
function turn.startBankerDraw(game)
    if not isLanMode(game) then
        return
    end
    
    -- Find who is banker
    local bankerRole = nil
    if perspective.amIBanker(game) then
        bankerRole = game.lan.role
    else
        bankerRole = perspective.getOpponentNetworkRole(game)
    end
    
    turn.startTurn(game, bankerRole)
    
    if perspective.amIBanker(game) then
        game.message = "Banker draw phase: choose Hit or Stand"
    else
        game.message = "Waiting for banker to draw..."
    end
    
    print(string.format("[Turn] Banker draw phase, banker is: %s", bankerRole))
end

-- Idle-player draw phase
function turn.startIdleDraw(game)
    if not isLanMode(game) then
        return
    end
    
    -- Find who is idle player
    local idleRole = nil
    if not perspective.amIBanker(game) then
        idleRole = game.lan.role
    else
        idleRole = perspective.getOpponentNetworkRole(game)
    end
    
    turn.startTurn(game, idleRole)
    
    if not perspective.amIBanker(game) then
        game.message = "Idle draw phase: choose Hit or Stand"
    else
        game.message = "Waiting for idle player to act..."
    end
    
    print(string.format("[Turn] Idle draw phase, idle player is: %s", idleRole))
end

-- Settlement phase
function turn.startSettlement(game)
    if not isLanMode(game) then
        return
    end
    
    game.currentPlayer = nil  -- No turn control during settlement
    game.message = "Resolving round..."
    
    print("[Turn] Enter settlement phase")
end

-- Enable/disable buttons according to current LAN turn state
function turn.updateButtons(game)
    if not isLanMode(game) or not game.buttons then
        return
    end
    
    local canOperate = turn.canOperate(game)
    
    for _, button in ipairs(game.buttons) do
        -- Enable/disable depending on button type and current state
        if button.id == "start" then
            -- Start new round: only host can trigger (or anyone, executed by host)
            button.enabled = (game.lan.role == "host")
        elseif button.id == "hit" or button.id == "stand" then
            -- Hit/Stand: only the active player may click
            button.enabled = canOperate
        end
    end
end

-- Debug helper: print turn-related information
function turn.debug(game)
    if not isLanMode(game) then
        print("[Turn] Local mode")
        return
    end
    
    print(string.format("[Turn] Current player: %s", tostring(game.currentPlayer)))
    print(string.format("[Turn] Can I operate: %s", tostring(turn.canOperate(game))))
    print(string.format("[Turn] Game state: %s", tostring(game.state)))
end

return turn

