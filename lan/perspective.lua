-- Player perspective management module
-- Provides the correct view for each player in LAN mode
local perspective = {}

-- Check whether the game is in LAN mode
local function isLanMode(game)
    return game.mode == "lan_game" and game.lan and game.lan.matchActive
end

-- Get my network role ("host" or "client")
function perspective.getMyNetworkRole(game)
    if not isLanMode(game) then
        return nil
    end
    return game.lan.role  -- "host" or "client"
end

-- Get opponent's network role
function perspective.getOpponentNetworkRole(game)
    if not isLanMode(game) then
        return nil
    end
    return game.lan.role == "host" and "client" or "host"
end

-- Get my in-game role ("banker" or "idle")
function perspective.getMyGameRole(game)
    if not isLanMode(game) then
        return game.humanRole  -- Local mode: keep original logic
    end
    
    -- Check whether roles have been decided
    if not game.rolesDecided then
        return nil
    end
    
    -- Read role information from roleDraw
    if game.roleDraw and game.roleDraw.roles then
        local myNetworkRole = game.lan.role
        return game.roleDraw.roles[myNetworkRole]
    end
    
    -- Fallback: infer from game state
    -- If player hands are stored in hostHand/guestHand
    if game.lan.role == "host" and game.hostRole then
        return game.hostRole
    elseif game.lan.role == "client" and game.guestRole then
        return game.guestRole
    end
    
    return nil
end

-- Get opponent's in-game role
function perspective.getOpponentGameRole(game)
    if not isLanMode(game) then
        return game.humanRole == "banker" and "idle" or "banker"  -- Local mode: opponent is AI
    end
    
    if not game.rolesDecided then
        return nil
    end
    
    if game.roleDraw and game.roleDraw.roles then
        local opponentNetworkRole = perspective.getOpponentNetworkRole(game)
        return game.roleDraw.roles[opponentNetworkRole]
    end
    
    -- Fallback inference
    local myRole = perspective.getMyGameRole(game)
    if myRole == "banker" then
        return "idle"
    elseif myRole == "idle" then
        return "banker"
    end
    
    return nil
end

-- Whether I am the banker
function perspective.amIBanker(game)
    return perspective.getMyGameRole(game) == "banker"
end

-- Whether the opponent is the banker
function perspective.isOpponentBanker(game)
    return perspective.getOpponentGameRole(game) == "banker"
end

-- Get my hand (based on network role)
function perspective.getMyHand(game)
    if not isLanMode(game) then
        return game.playerHand  -- Local mode
    end
    
    -- LAN mode: return the hand that matches my network role
    if game.lan.role == "host" then
        return game.hostHand or game.playerHand  -- Backward compatibility
    else
        return game.guestHand or game.playerHand
    end
end

-- Get opponent's hand
function perspective.getOpponentHand(game)
    if not isLanMode(game) then
        return game.opponentHand  -- Local mode
    end
    
    if game.lan.role == "host" then
        return game.guestHand or game.opponentHand
    else
        return game.hostHand or game.opponentHand
    end
end

-- Whether it is my turn to act
function perspective.isMyTurn(game)
    if not isLanMode(game) then
        return true  -- Local mode: the human can always act
    end
    
    -- Check current state
    if game.state == "await_start" then
        return true  -- Anyone can click "Start New Round" (host actually controls)
    end
    
    if game.state == "round_over" or game.state == "match_over" then
        return true  -- Settlement phase
    end
    
    -- Role-draw phase: both can flip their own card
    if game.roleDraw and game.roleDraw.stage then
        return true  -- Both may act here (only on their own card)
    end
    
    -- During play: rely on currentPlayer
    if game.currentPlayer then
        return game.currentPlayer == game.lan.role
    end
    
    -- Fallback logic: use game state and roles
    if game.state == "player_turn" then
        -- In banker turn, only banker may act
        local myRole = perspective.getMyGameRole(game)
        return myRole == "banker" or myRole == "idle"  -- Kept for compatibility, may be refined
    end
    
    if game.state == "dealer_turn" then
        -- Banker turn, only banker may act
        return perspective.amIBanker(game)
    end
    
    return false
end

-- Get the turn-related hint text for the local player
function perspective.getTurnMessage(game)
    if not isLanMode(game) then
        return game.message  -- Local mode uses existing message
    end
    
    if perspective.isMyTurn(game) then
        return "It is your turn"
    else
        return "Waiting for opponent to act..."
    end
end

-- Get my lives (for the current perspective)
function perspective.getMyLives(game)
    if not isLanMode(game) then
        local myRole = game.humanRole
        return myRole == "banker" and game.dealerLives or game.playerLives
    end
    
    -- LAN mode
    if game.lan.role == "host" then
        return game.hostLives or game.playerLives
    else
        return game.guestLives or game.playerLives
    end
end

-- Get opponent lives
function perspective.getOpponentLives(game)
    if not isLanMode(game) then
        local myRole = game.humanRole
        return myRole == "banker" and game.playerLives or game.dealerLives
    end
    
    if game.lan.role == "host" then
        return game.guestLives or game.dealerLives
    else
        return game.hostLives or game.dealerLives
    end
end

-- Get my match win count
function perspective.getMyMatchWins(game)
    if not isLanMode(game) then
        return game.humanMatchWins
    end
    
    if game.lan.role == "host" then
        return game.hostMatchWins or 0
    else
        return game.guestMatchWins or 0
    end
end

-- Get opponent match win count
function perspective.getOpponentMatchWins(game)
    if not isLanMode(game) then
        return game.aiMatchWins
    end
    
    if game.lan.role == "host" then
        return game.guestMatchWins or 0
    else
        return game.hostMatchWins or 0
    end
end

-- Set which network role is currently active ("host" or "client")
function perspective.setCurrentPlayer(game, networkRole)
    if isLanMode(game) then
        game.currentPlayer = networkRole  -- "host" or "client"
    end
end

-- Switch to the opponent's turn
function perspective.switchToOpponent(game)
    if isLanMode(game) then
        local current = game.currentPlayer or game.lan.role
        game.currentPlayer = (current == "host") and "client" or "host"
    end
end

-- Debug helper: print perspective-related information
function perspective.debug(game)
    if not isLanMode(game) then
        print("[Perspective] Local mode")
        return
    end
    
    print(string.format("[Perspective] My network role: %s", game.lan.role))
    print(string.format("[Perspective] My game role: %s", tostring(perspective.getMyGameRole(game))))
    print(string.format("[Perspective] Opponent game role: %s", tostring(perspective.getOpponentGameRole(game))))
    print(string.format("[Perspective] Is it my turn: %s", tostring(perspective.isMyTurn(game))))
    print(string.format("[Perspective] My lives: %d", perspective.getMyLives(game)))
    print(string.format("[Perspective] Opponent lives: %d", perspective.getOpponentLives(game)))
end

return perspective

