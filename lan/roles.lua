-- Role mapping module
-- Manages mapping between network roles (host/client) and game roles (banker/idle)
local roles = {}

-- Check whether the game is in LAN mode
local function isLanMode(game)
    return game.mode == "lan_game" and game.lan and game.lan.matchActive
end

-- Initialize role system for LAN mode
function roles.initialize(game)
    if not isLanMode(game) then
        return
    end
    
    -- Note: do not create game.roleDraw here!
    -- roleDraw should be created by game_logic.beginRoleDraw.
    -- Only initialize lives and win counts here.
    
    -- Initialize lives if missing
    if not game.hostLives then
        local config = require("config")
        game.hostLives = config.GAME.initialLives
        game.guestLives = config.GAME.initialLives
    end
    
    -- Initialize match win counts
    game.hostMatchWins = game.hostMatchWins or 0
    game.guestMatchWins = game.guestMatchWins or 0
    
    print("[Roles] Role system initialized (waiting for role-draw cards)")
end

-- Assign roles (called after the role-draw result is known)
-- @param winner: "host" or "client", the player who wins the role-draw
function roles.assignRoles(game, winner)
    if not isLanMode(game) then
        return
    end
    
    -- roleDraw should already have been created by beginRoleDraw
    if not game.roleDraw then
        print("[Roles] Warning: roleDraw does not exist; cannot assign roles!")
        return
    end
    
    -- Ensure roles sub-table exists
    if not game.roleDraw.roles then
        game.roleDraw.roles = {}
    end
    
    -- Winner of role-draw becomes banker
    game.roleDraw.roles[winner] = "banker"
    local loser = (winner == "host") and "client" or "host"
    game.roleDraw.roles[loser] = "idle"
    
    -- Mark roles as decided
    game.rolesDecided = true
    
    print(string.format("[Roles] Role assignment complete: %s=banker, %s=idle", winner, loser))
    
    -- Update message from local player's perspective
    if game.lan.role == winner then
        game.message = "You are the banker"
    else
        game.message = "You are the idle player"
    end
end

-- Swap roles (called after a match ends)
function roles.swapRoles(game)
    if not isLanMode(game) then
        return
    end
    
    if not game.roleDraw or not game.roleDraw.roles then
        print("[Roles] Warning: role data does not exist; cannot swap")
        return
    end
    
    -- Swap roles
    local temp = game.roleDraw.roles.host
    game.roleDraw.roles.host = game.roleDraw.roles.client
    game.roleDraw.roles.client = temp
    
    print(string.format("[Roles] Role swap complete: host=%s, client=%s", 
        game.roleDraw.roles.host, game.roleDraw.roles.client))
    
    -- Update message for local player
    local myNewRole = game.roleDraw.roles[game.lan.role]
    if myNewRole == "banker" then
        game.message = "Roles swapped: you are now the banker"
    else
        game.message = "Roles swapped: you are now the idle player"
    end
end

-- Get game role for a given network role
-- @param networkRole: "host" or "client"
-- @return: "banker" or "idle" or nil
function roles.getGameRole(game, networkRole)
    if not isLanMode(game) then
        return nil
    end
    
    if not game.rolesDecided then
        return nil
    end
    
    if game.roleDraw and game.roleDraw.roles then
        return game.roleDraw.roles[networkRole]
    end
    
    return nil
end

-- Get my game role
function roles.getMyRole(game)
    if not isLanMode(game) then
        return game.humanRole  -- Local mode
    end
    
    return roles.getGameRole(game, game.lan.role)
end

-- Get opponent's game role
function roles.getOpponentRole(game)
    if not isLanMode(game) then
        local myRole = game.humanRole
        return myRole == "banker" and "idle" or "banker"
    end
    
    local opponentNetworkRole = (game.lan.role == "host") and "client" or "host"
    return roles.getGameRole(game, opponentNetworkRole)
end

-- Whether I am the banker
function roles.amIBanker(game)
    return roles.getMyRole(game) == "banker"
end

-- Whether I am the idle player
function roles.amIIdle(game)
    return roles.getMyRole(game) == "idle"
end

-- Get network role by game role
-- @param gameRole: "banker" or "idle"
-- @return: "host" or "client" or nil
function roles.getNetworkRoleByGameRole(game, gameRole)
    if not isLanMode(game) or not game.rolesDecided then
        return nil
    end
    
    if not game.roleDraw or not game.roleDraw.roles then
        return nil
    end
    
    for networkRole, gr in pairs(game.roleDraw.roles) do
        if gr == gameRole then
            return networkRole
        end
    end
    
    return nil
end

-- Get the banker's network role
function roles.getBankerNetworkRole(game)
    return roles.getNetworkRoleByGameRole(game, "banker")
end

-- Get the idle player's network role
function roles.getIdleNetworkRole(game)
    return roles.getNetworkRoleByGameRole(game, "idle")
end

-- Get display name for a given network role
function roles.getPlayerName(game, networkRole)
    if not game.lan or not game.lan.players then
        return networkRole == "host" and "Host" or "Opponent"
    end
    
    local player = nil
    if networkRole == "host" then
        player = game.lan.players.host
    else
        player = game.lan.players.guest
    end
    
    return player and player.name or (networkRole == "host" and "Host" or "Opponent")
end

-- Get my display name
function roles.getMyName(game)
    if not isLanMode(game) then
        return "You"
    end
    
    return roles.getPlayerName(game, game.lan.role)
end

-- Get opponent's display name
function roles.getOpponentName(game)
    if not isLanMode(game) then
        return "AI"
    end
    
    local opponentRole = (game.lan.role == "host") and "client" or "host"
    return roles.getPlayerName(game, opponentRole)
end

-- Reset roles (called when a new match starts)
function roles.reset(game)
    if not isLanMode(game) then
        return
    end
    
    if game.roleDraw then
        game.roleDraw.roles = {
            host = nil,
            client = nil,
        }
    end
    
    game.rolesDecided = false
    
    print("[Roles] Roles reset")
end

-- Debug helper: print role information
function roles.debug(game)
    if not isLanMode(game) then
        print("[Roles] Local mode")
        return
    end
    
    print("[Roles] ========== Role info ==========")
    print(string.format("[Roles] Roles decided: %s", tostring(game.rolesDecided)))
    
    if game.roleDraw and game.roleDraw.roles then
        print(string.format("[Roles] Host role: %s", tostring(game.roleDraw.roles.host)))
        print(string.format("[Roles] Client role: %s", tostring(game.roleDraw.roles.client)))
    end
    
    print(string.format("[Roles] My network role: %s", game.lan.role))
    print(string.format("[Roles] My game role: %s", tostring(roles.getMyRole(game))))
    print(string.format("[Roles] Opponent game role: %s", tostring(roles.getOpponentRole(game))))
    print("[Roles] ===================================")
end

return roles

