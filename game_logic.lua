-- Game rules and turn logic
local game_logic = {}
local card_module = require("card")
local config = require("config")
local utils = require("utils")
local ai = require("ai")

-- LAN game modules
local perspective = require("lan.perspective")
local turn = require("lan.turn")
local roles = require("lan.roles")

local ddzRankOrder = {
    ["Big Joker"] = 17,
    ["Small Joker"] = 16,
    ["2"] = 15,
    ["A"] = 14,
    ["K"] = 13,
    ["Q"] = 12,
    ["J"] = 11,
    ["10"] = 10,
    ["9"] = 9,
    ["8"] = 8,
    ["7"] = 7,
    ["6"] = 6,
    ["5"] = 5,
    ["4"] = 4,
    ["3"] = 3,
}

local function getRoleDrawRankValue(card)
    if not card or not card.rank then
        return 0
    end
    return ddzRankOrder[card.rank] or 0
end

local function compareRoleDrawCards(cardA, cardB)
    local valueA = getRoleDrawRankValue(cardA)
    local valueB = getRoleDrawRankValue(cardB)
    if valueA == valueB then
        return 0
    end
    return valueA > valueB and 1 or -1
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end


local function getRoleDrawTargets()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local centerX = w / 2
    local targetY = h / 2 - config.CARD.height / 2
    local offsetY = (config.ROLE_DRAW and config.ROLE_DRAW.offsetY) or 0
    targetY = targetY + offsetY
    local gap = config.CARD.width + 120
    local halfGap = gap / 2
    local halfWidth = config.CARD.width / 2
    local humanTargetX = centerX - halfGap - halfWidth
    local aiTargetX = centerX + halfGap - halfWidth
    return humanTargetX, aiTargetX, targetY
end

local function prepareRoleDrawCard(game, cardData, targetX, targetY, delay)
    local drawPile = game.zones and game.zones.drawPile
    cardData.owner = "role_draw"
    cardData.container = "role_draw"
    cardData.draggable = false
    cardData.faceDown = true
    if drawPile then
        cardData.x = drawPile.x
        cardData.y = drawPile.y
    end
    cardData.targetX = targetX
    cardData.targetY = targetY
    cardData.moveDelay = delay or 0
    return cardData
end

local function roleDrawCardNearTarget(card)
    if not card then
        return false
    end
    if card.moveDelay and card.moveDelay > 0 then
        return false
    end
    local cx = card.x or card.targetX or 0
    local cy = card.y or card.targetY or 0
    local tx = card.targetX or 0
    local ty = card.targetY or 0
    return math.abs(cx - tx) < 1 and math.abs(cy - ty) < 1
end

local function pointOnCard(card, px, py)
    if not card then
        return false
    end
    local cx = card.x or card.targetX or 0
    local cy = card.y or card.targetY or 0
    return px >= cx and px <= (cx + config.CARD.width) and py >= cy and py <= (cy + config.CARD.height)
end

local function finalizeRoleAssignment(game, roleDraw)
    roleDraw.stage = "resolved"
    local isLan = game_logic.isLanMode(game)
    
    if isLan then
        -- In LAN mode, use the roles module to assign roles
        local comparison = roleDraw.comparison
        local isHost = game.lan and game.lan.role == "host"
        -- comparison > 0 means my card is higher (I win the draw)
        -- If I am the host, comparison > 0 means the host wins
        -- If I am the client, comparison > 0 means the client wins
        local winner
        if (isHost and comparison > 0) or (not isHost and comparison > 0) then
            -- I win the role draw
            winner = game.lan.role  -- "host" or "client"
        else
            -- Opponent wins the role draw
            winner = (game.lan.role == "host") and "client" or "host"
        end
        
        -- Assign roles using the roles module
        roles.assignRoles(game, winner)
        
        -- Also set humanRole (for backward compatibility)
        local iAmBanker = roles.amIBanker(game)
        game.humanRole = iAmBanker and "banker" or "idle"
        
        roleDraw.myRevealed = true
        roleDraw.opponentRevealed = true
        game.rolesDecided = true
        
        local myCardLabel = roleDraw.myCard and roleDraw.myCard.label or "?"
        local opponentCardLabel = roleDraw.opponentCard and roleDraw.opponentCard.label or "?"
        local bankerText = iAmBanker and "You" or "Opponent"
        local idleText = iAmBanker and "Opponent" or "You"
        
        game.message = string.format(
            "Role draw result: you drew %s, opponent drew %s. %s becomes banker, %s becomes idle. Click \"Start New Round\" to begin dealing.",
            myCardLabel,
            opponentCardLabel,
            bankerText,
            idleText)
        
        -- Debug output
        roles.debug(game)
    else
        -- Local (single-player) mode
        local winner = roleDraw.winner
        if winner == "human" then
            game.humanRole = "banker"
        else
            game.humanRole = "idle"
        end
        roleDraw.humanRole = game.humanRole
        roleDraw.aiRole = (game.humanRole == "banker") and "idle" or "banker"
        roleDraw.humanRevealed = true
        roleDraw.aiRevealed = true
        game.rolesDecided = true
        local bankerText = (winner == "human") and "You" or "Opponent"
        local idleText = (winner == "human") and "Opponent" or "You"
        game.message = string.format(
            "Role draw result: you drew %s, opponent drew %s. %s becomes banker, %s becomes idle. Click \"Start New Round\" to begin dealing.",
            roleDraw.humanCard.label,
            roleDraw.aiCard.label,
            bankerText,
            idleText)
    end
end

local function startCardFlip(card, targetFaceDown)
    if not card then
        return
    end
    card.isFlipping = true
    card.flipElapsed = 0
    card.flipDuration = card.flipDuration or 0.45
    card.flipTargetFaceDown = targetFaceDown
    card.flipSwapped = (targetFaceDown == nil) or (targetFaceDown == card.faceDown)
end

local function revealOpponentHand(game)
    if game.revealDealer then
        return
    end
    game.revealDealer = true
    for _, card in ipairs(game.opponentHand) do
        if card.faceDown then
            startCardFlip(card, false)
        end
    end
end

function game_logic.beginRoleDraw(game, ui)
    local isLan = game_logic.isLanMode(game)
    if isLan then
        print(string.format("[BeginRoleDraw] caller: %s", game.lan.role))
    end
    
    game.roleDraw = nil
    game.draggedCard = nil
    game.highlightedCard = nil
    game.dealerPeekLog = {}
    game.dealerInitialCount = 0
    game.nextOpponentDealDelay = 0
    game.revealDealer = false
    game.playerHand = {}
    game.opponentHand = {}
    game.boardCards = {}
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    ui.layoutBoard(game.boardCards, game.zones.playArea)
    
    -- In LAN mode: only the host generates role-draw cards, then syncs to clients
    if isLan and game.lan.role ~= "host" then
        -- Client: wait to receive host's synced state
        print("[BeginRoleDraw] client waiting for host sync...")
        game.message = "Waiting for host to deal role-draw cards..."
        game.rolesDecided = false
        game.state = "await_start"
        return
    end
    
    print("[BeginRoleDraw] generating role-draw cards...")

    
    local myCard
    local opponentCard
    local comparison = 0
    repeat
        game_logic.ensureDeckHas(game, 2)
        myCard = table.remove(game.deck)
        opponentCard = table.remove(game.deck)
        comparison = compareRoleDrawCards(myCard, opponentCard)
    until comparison ~= 0

    local humanTargetX, aiTargetX, targetY = getRoleDrawTargets()
    
    -- In LAN mode, choose card positions based on the current player's role
    if isLan then
        local isHost = game.lan and game.lan.role == "host"
        local myTargetX, opponentTargetX
        if isHost then
            -- Host: my card on the left, opponent on the right
            myTargetX = humanTargetX
            opponentTargetX = aiTargetX
        else
            -- Client: my card on the right, opponent on the left
            myTargetX = aiTargetX
            opponentTargetX = humanTargetX
        end
        myCard = prepareRoleDrawCard(game, myCard, myTargetX, targetY, 0)
        opponentCard = prepareRoleDrawCard(game, opponentCard, opponentTargetX, targetY, 0)
        
        game.roleDraw = {
            cards = {myCard, opponentCard},
            myCard = myCard,
            opponentCard = opponentCard,
            myRevealed = false,
            opponentRevealed = false,
            stage = "dealing",
            comparison = comparison, -- Save comparison result for final resolution
        }
        game.message = "Dealing role-draw cards..."
        
        -- Host immediately syncs state
        print(string.format("[BeginRoleDraw] role-draw cards generated: myCard=%s, opponentCard=%s, comparison=%d", 
            myCard.label, opponentCard.label, comparison))
        print("[BeginRoleDraw] host syncing role-draw state...")
        local lan_mode = require("modes.lan_mode")
        lan_mode.sync(game)
        print("[BeginRoleDraw] host sync complete")
    else
        -- Local mode: humanCard and aiCard
        myCard = prepareRoleDrawCard(game, myCard, humanTargetX, targetY, 0)
        opponentCard = prepareRoleDrawCard(game, opponentCard, aiTargetX, targetY, 0)
        
        game.roleDraw = {
            cards = {myCard, opponentCard},
            humanCard = myCard,
            aiCard = opponentCard,
            winner = comparison > 0 and "human" or "ai",
            stage = "dealing",
            humanRevealed = false,
            aiRevealed = false,
        }
        game.message = "Dealing role-draw cards..."
    end

    game.rolesDecided = false
    game.state = "await_start"

    game.deck = card_module.buildDeck()
    utils.shuffle(game.deck)
end

function game_logic.updateRoleDraw(game, dt)
    local roleDraw = game.roleDraw
    if not roleDraw then
        return
    end
    local isLan = game_logic.isLanMode(game)
    
    if roleDraw.stage == "dealing" then
        local myCard = isLan and roleDraw.myCard or roleDraw.humanCard
        local opponentCard = isLan and roleDraw.opponentCard or roleDraw.aiCard
        if myCard and opponentCard and myCard.moveDelay == 0 then
            -- no-op, kept for clarity
        end
        if roleDrawCardNearTarget(myCard) and roleDrawCardNearTarget(opponentCard) then
            if isLan then
                roleDraw.stage = "await_players"
            else
                roleDraw.stage = "await_player"
            end
            game.message = "Please click your role-draw card to reveal it"
        end
    elseif roleDraw.stage == "await_player" then
        -- Local mode: wait for the player to click
        -- In this stage we only show a message; clicking enters player_flipping
    elseif roleDraw.stage == "player_flipping" then
        -- Local mode: human flip animation in progress
        if not roleDraw.humanCard.isFlipping then
            roleDraw.humanRevealed = true
            roleDraw.stage = "ai_flipping"
            startCardFlip(roleDraw.aiCard, false)
            game.message = "Opponent's role-draw card is being revealed..."
        end
    elseif roleDraw.stage == "ai_flipping" then
        -- Local mode: AI flip animation in progress
        if not roleDraw.aiCard.isFlipping then
            roleDraw.aiRevealed = true
            finalizeRoleAssignment(game, roleDraw)
        end
    elseif roleDraw.stage == "await_players" then
        -- In LAN mode: wait until both players have revealed
        if isLan then
            if roleDraw.myRevealed and roleDraw.opponentRevealed then
                -- Both are revealed; finalize
                finalizeRoleAssignment(game, roleDraw)
            elseif roleDraw.myRevealed then
                game.message = "Waiting for opponent to reveal their role-draw card..."
            elseif roleDraw.opponentRevealed then
                game.message = "Please click your role-draw card to reveal it"
            else
                game.message = "Please click your role-draw card to reveal it"
            end
        end
    end
end

function game_logic.handleRoleDrawClick(game, x, y)
    local roleDraw = game.roleDraw
    if not roleDraw then
        return false
    end
    local isLan = game_logic.isLanMode(game)
    
    if isLan then
        -- In LAN mode: only allow clicking your own card during await_players stage
        if roleDraw.stage ~= "await_players" then
            return false
        end
        if roleDraw.myCard and pointOnCard(roleDraw.myCard, x, y) and not roleDraw.myRevealed then
            roleDraw.myRevealed = true
            startCardFlip(roleDraw.myCard, false)
            game.message = "You have revealed your role-draw card..."
            -- Sync flip operation via network
            local lan_mode = require("modes.lan_mode")
            if game.lan and game.lan.role == "host" then
                lan_mode.sync(game)
            elseif game.lan and game.lan.role == "client" then
                local client = require("lan.client")
                client.sendAction({type = "role_draw_flip"})
            end
            return true
        end
    else
        -- Local mode: clicking humanCard, stage is await_player
        if roleDraw.stage ~= "await_player" then
            return false
        end
        if roleDraw.humanCard and pointOnCard(roleDraw.humanCard, x, y) then
            roleDraw.stage = "player_flipping"
            startCardFlip(roleDraw.humanCard, false)
            game.message = "You have revealed your role-draw card..."
            return true
        end
    end
    return false
end

function game_logic.isHumanBanker(game)
    return game.humanRole == "banker"
end

function game_logic.humanLabel(game)
    return game_logic.isHumanBanker(game) and "Banker (You)" or "Idle (You)"
end

function game_logic.aiLabel(game)
    return game_logic.isHumanBanker(game) and "Idle (Opponent)" or "Banker (Opponent)"
end

-- Wrapper for ai module decision functions to keep the interface consistent
function game_logic.dealerShouldContinue(currentValue, game)
    return ai.dealerShouldContinue(currentValue, game)
end

function game_logic.aiIdleShouldContinue(currentValue, game)
    return ai.idleShouldContinue(currentValue, game)
end

function game_logic.ensureDeckHas(game, minCards)
    if not game.deck or #game.deck < minCards then
        game.deck = card_module.buildDeck()
        utils.shuffle(game.deck)
        return true
    end
    return false
end

function game_logic.dealCard(game, owner, ui)
    game_logic.ensureDeckHas(game, 1)
    local card = table.remove(game.deck)
    if not card then
        game.message = "The deck is empty. Please start a new round."
        return
    end
    
    local isLan = game_logic.isLanMode(game)
    
    card.owner = owner
    card.draggable = owner == "player"
    if owner == "player" then
        card.faceDown = false
    else
        if game_logic.isHumanBanker(game) then
            card.faceDown = false
        else
            card.faceDown = not game.revealDealer
        end
    end
    card.x = game.zones.drawPile.x
    card.y = game.zones.drawPile.y
    card.targetX = card.x
    card.targetY = card.y
    
    if owner == "player" then
        card.moveDelay = 0
        table.insert(game.playerHand, card)
        ui.layoutHand(game.playerHand, game.zones.playerHand, game)
        
        -- In LAN mode: also update the corresponding network player's hand
        if isLan then
            if game.lan.role == "host" then
                game.hostHand = game.hostHand or {}
                table.insert(game.hostHand, card)
            else
                game.guestHand = game.guestHand or {}
                table.insert(game.guestHand, card)
            end
        end
    else
        local interval = (config.DEAL_ANIMATION and config.DEAL_ANIMATION.opponentInterval) or 0.1
        card.moveDelay = game.nextOpponentDealDelay or 0
        game.nextOpponentDealDelay = (game.nextOpponentDealDelay or 0) + interval
        table.insert(game.opponentHand, card)
        ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
        
        -- In LAN mode: also update the corresponding network player's hand
        if isLan then
            if game.lan.role == "host" then
                game.guestHand = game.guestHand or {}
                table.insert(game.guestHand, card)
            else
                game.hostHand = game.hostHand or {}
                table.insert(game.hostHand, card)
            end
        end
    end
    return card
end

function game_logic.dealerInitialDraw(game, ui)
    local isLan = game_logic.isLanMode(game)
    
    -- If the banker is a human player (local or LAN), do not auto-draw
    if game_logic.isHumanBanker(game) then
        return true
    end
    
    -- In LAN mode, the opponent is human, so do not execute AI logic
    if isLan then
        return true
    end
    
    -- Local mode: call AI module's banker initial draw logic
    return ai.dealerInitialDraw(game, ui, game_logic.dealCard)
end

function game_logic.aiIdlePlay(game, ui)
    -- Call AI module's idle-player action logic
    ai.idlePlay(game, ui, game_logic.dealCard, game_logic.ensureDeckHas)
end

function game_logic.evaluateOutcome(game)
    local humanValue, humanCount = card_module.evaluateHand(game.playerHand)
    local aiValue, aiCount = card_module.evaluateHand(game.opponentHand)
    local humanFive = humanCount >= 5 and humanValue <= game.maxValue
    local aiFive = aiCount >= 5 and aiValue <= game.maxValue
    local epsilon = 0.001
    local humanPerfect = math.abs(humanValue - game.maxValue) <= epsilon
    local aiPerfect = math.abs(aiValue - game.maxValue) <= epsilon
    local humanBust = humanValue > game.maxValue
    local aiBust = aiValue > game.maxValue
    local bankerIsHuman = game_logic.isHumanBanker(game)

    if humanPerfect and not aiPerfect then
        return game_logic.humanLabel(game) .. " reaches exactly 10.5 points and immediately wins this round", "player", 3
    elseif aiPerfect and not humanPerfect then
        return game_logic.aiLabel(game) .. " reaches exactly 10.5 points and immediately wins this round", "dealer", 3
    end

    if humanBust and not aiBust then
        return game_logic.humanLabel(game) .. " busts, " .. game_logic.aiLabel(game) .. " wins", "dealer", 1
    elseif aiBust and not humanBust then
        return game_logic.aiLabel(game) .. " busts, " .. game_logic.humanLabel(game) .. " wins", "player", 1
    elseif humanBust and aiBust then
        if bankerIsHuman then
            return "Both players bust; banker advantage gives " .. game_logic.humanLabel(game) .. " the win", "player", 1
        else
            return "Both players bust; banker advantage gives " .. game_logic.aiLabel(game) .. " the win", "dealer", 1
        end
    end

    if humanFive and not aiFive then
        return game_logic.humanLabel(game) .. " has five cards without busting and wins", "player", 1
    elseif aiFive and not humanFive then
        return game_logic.aiLabel(game) .. " has five cards without busting and wins", "dealer", 1
    end

    if humanValue > aiValue then
        return game_logic.humanLabel(game) .. " has a higher total and wins", "player", 1
    elseif humanValue < aiValue then
        return game_logic.aiLabel(game) .. " has a higher total and wins", "dealer", 1
    else
        if bankerIsHuman then
            return "Totals are equal; banker advantage gives " .. game_logic.humanLabel(game) .. " the win", "player", 1
        else
            return "Totals are equal; banker advantage gives " .. game_logic.aiLabel(game) .. " the win", "dealer", 1
        end
    end
end

function game_logic.concludeRound(game, resultText, winner, damage, ui)
    revealOpponentHand(game)
    ai.recordHumanCardStats(game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)

    local moodCfg = ai.getAiBehaviorSection("mood")
    local confidenceStep = moodCfg.confidenceStep or 0
    local confidenceClamp = moodCfg.confidenceClamp or 0.3
    if winner == "dealer" then
        -- AI won this round, raise confidence slightly
        game.aiConfidence = clamp((game.aiConfidence or 0) + confidenceStep, -confidenceClamp, confidenceClamp)
    elseif winner == "player" then
        -- Player won this round, reduce AI confidence
        game.aiConfidence = clamp((game.aiConfidence or 0) - confidenceStep, -confidenceClamp, confidenceClamp)
    end

    game.state = "round_over"
    game.message = string.format("%s. Click \"Start New Round\" to continue.", resultText or "")
end

local function collectCardsForClear(game)
    local clones = {}
    local function addCards(hand)
        for _, card in ipairs(hand) do
            local clone = utils.shallowCopy(card)
            clone.renderX = card.x
            clone.renderY = card.y
            clone.renderAlpha = 1
            clone.renderScale = 1
            clone.disableHoverEffect = true
            clone.disableIdleWobble = true
            table.insert(clones, clone)
        end
    end
    addCards(game.playerHand)
    addCards(game.opponentHand)
    addCards(game.boardCards)
    return clones
end

local function performRoundSetup(game, ui)
    game_logic.ensureDeckHas(game, 4)
    game.roleDraw = nil
    game.nextOpponentDealDelay = 0
    local moodCfg = ai.getAiBehaviorSection("mood")
    local range = moodCfg.roundRange or 0.2
    game.aiRoundMood = range ~= 0 and (love.math.random() * 2 * range - range) or 0
    game.revealDealer = game_logic.isHumanBanker(game)
    game.playerHand = {}
    game.opponentHand = {}
    game.boardCards = {}
    game.draggedCard = nil
    game.highlightedCard = nil
    game.dealerInitialCount = 0
    game.dealerPeekLog = {}
    
    -- In LAN mode: initialize network player hands
    local isLan = game_logic.isLanMode(game)
    if isLan then
        game.hostHand = {}
        game.guestHand = {}
    end
    
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    if not game_logic.dealerInitialDraw(game, ui) then
        return
    end
    game.state = "player_turn"
    
    -- In LAN mode: use the turn module to control turns
    if isLan then
        -- Determine who is banker so they can act first
        local bankerNetworkRole = roles.getBankerNetworkRole(game)
        if bankerNetworkRole then
            turn.startTurn(game, bankerNetworkRole)
            if roles.amIBanker(game) then
                game.message = "You are the banker. Click \"Hit\" to draw cards, or \"Stand\" to let the idle player act."
            else
                game.message = "Waiting for the banker to act..."
            end
        else
            -- Roles not yet decided; use default message
            game.message = "Click \"Hit\" to start drawing cards"
        end
    else
        -- Local mode: use existing logic
        if game_logic.isHumanBanker(game) then
            game.message = "You are the banker. Click \"Hit\" to draw cards, or \"Stand\" to let the idle player act."
        else
            game.message = string.format("The banker has drawn %d cards and kept them face down. Click \"Hit\" to start drawing cards.", game.dealerInitialCount)
        end
    end
end

function game_logic.startClearAnimation(game, ui, onComplete)
    local clones = collectCardsForClear(game)
    if #clones == 0 then
        if onComplete then
            onComplete()
        end
        return
    end
    local animation = {
        active = true,
        cards = clones,
        elapsed = 0,
        moveDuration = 0.35,
        shatterDuration = 0.35,
        shatterInterval = 0.08,
        onComplete = onComplete,
    }
    for index, clone in ipairs(clones) do
        clone.clearStartX = clone.renderX or clone.x or 0
        clone.clearStartY = clone.renderY or clone.y or 0
        clone.clearTargetX = clone.clearStartX - (config.CARD.width * 2 + 120)
        clone.clearDelay = (index - 1) * animation.shatterInterval
    end
    game.clearAnimation = animation
    game.playerHand = {}
    game.opponentHand = {}
    game.boardCards = {}
    game.draggedCard = nil
    game.highlightedCard = nil
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    ui.layoutBoard(game.boardCards, game.zones.playArea)
    game.state = "clearing"
    game.message = "Preparing to deal cards..."
end

function game_logic.startRound(game, ui)
    local isLan = game_logic.isLanMode(game)
    if isLan then
        print(string.format("[StartRound] caller: %s, rolesDecided: %s, roleDraw: %s", 
            game.lan.role, tostring(game.rolesDecided), game.roleDraw and game.roleDraw.stage or "nil"))
    end
    
    if game.screen ~= "table" then
        return
    end
    if not game.rolesDecided then
        if not game.roleDraw then
            print("[StartRound] no role-draw cards, generating...")
            game_logic.beginRoleDraw(game, ui)
            print(string.format("[StartRound] beginRoleDraw completed, roleDraw: %s", game.roleDraw and game.roleDraw.stage or "nil"))
        else
            if game.roleDraw.stage ~= "resolved" then
                print(string.format("[StartRound] role-draw stage: %s", game.roleDraw.stage))
                if game.roleDraw.stage == "await_player" or game.roleDraw.stage == "await_players" then
                    game.message = "Please click your role-draw card to reveal it first."
                elseif game.roleDraw.stage == "player_flipping" then
                    game.message = "Revealing your role-draw card..."
                elseif game.roleDraw.stage == "ai_flipping" then
                    game.message = "Waiting for opponent to reveal their role-draw card..."
                elseif game.roleDraw.stage == "dealing" then
                    game.message = "Dealing role-draw cards..."
                else
                    game.message = "Preparing role-draw cards..."
                end
            else
                -- Resolved but rolesDecided was not updated (safety guard)
                print("[StartRound] role-draw resolved; finalizing role assignment")
                finalizeRoleAssignment(game, game.roleDraw)
            end
        end
        return
    end
    -- Check if a clear animation is in progress
    if game.clearAnimation and game.clearAnimation.active then
        return
    end
    
    -- Check if any card movement animation is in progress
    if game_logic.hasCardsMoving(game) then
        game.message = "Please wait for the dealing animation to finish before starting a new round."
        return
    end
    local hasCards = (#game.playerHand > 0) or (#game.opponentHand > 0) or (#game.boardCards > 0)
    if hasCards then
        game_logic.startClearAnimation(game, ui, function()
            performRoundSetup(game, ui)
        end)
    else
        performRoundSetup(game, ui)
    end
end

function game_logic.playerHit(game, ui)
    if game.state ~= "player_turn" then
        return
    end
    local isBankerTurn = game_logic.isHumanBanker(game)
    local currentCount = #game.playerHand
    if isBankerTurn and currentCount >= game.maxBankerCards then
        game.message = "The banker may hold at most " .. tostring(game.maxBankerCards) .. " cards. Please click \"Stand\" to let the idle player act."
        return
    end
    local card = game_logic.dealCard(game, "player", ui)
    if not card then
        return
    end
    
    local isLan = game_logic.isLanMode(game)
    local value, count = card_module.evaluateHand(game.playerHand)
    
    if not isBankerTurn then
        if value > game.maxValue then
            game_logic.concludeRound(game, "Player busts, banker wins", "dealer", nil, ui)
            -- In LAN mode: sync state
            if isLan then
                local lan_mode = require("modes.lan_mode")
                if game.lan.role == "host" then
                    lan_mode.sync(game)
                end
            end
            return
        end
        if count >= 5 and value <= game.maxValue then
            game_logic.concludeRound(game, "Player five-card under 10.5, player wins", "player", nil, ui)
            -- In LAN mode: sync state
            if isLan then
                local lan_mode = require("modes.lan_mode")
                if game.lan.role == "host" then
                    lan_mode.sync(game)
                end
            end
            return
        end
        game.message = game_logic.humanLabel(game) .. " current total: " .. card_module.formatValue(value) .. ". Choose your next action."
    else
        if count >= game.maxBankerCards then
            game.message = game_logic.humanLabel(game) .. " has drawn " .. tostring(game.maxBankerCards) .. " cards; standing is recommended so the idle player can act."
        elseif value > game.maxValue then
            game.message = game_logic.humanLabel(game) .. " current total: " .. card_module.formatValue(value) .. " (busted; you may still draw or stand)."
        else
            game.message = game_logic.humanLabel(game) .. " current total: " .. card_module.formatValue(value) .. ". Choose your next action."
        end
    end
    
    -- In LAN mode: sync state
    if isLan then
        local lan_mode = require("modes.lan_mode")
        if game.lan.role == "host" then
            lan_mode.sync(game)
        else
            local client = require("lan.client")
            client.sendAction({type = "hit"})
        end
    end
end

function game_logic.isLanMode(game)
    return game.mode == "lan_game" and game.lan and game.lan.matchActive
end

-- Check if any cards are currently being dealt (excluding hover effects)
function game_logic.hasCardsMoving(game)
    -- Only check for cards that are waiting on deal delay
    -- This ignores the small movement caused by hover effects
    
    -- Check player hand
    for _, card in ipairs(game.playerHand) do
        if card.moveDelay and card.moveDelay > 0 then
            return true
        end
        -- Check for significant movement (ignore minor hover effects)
        if card.x and card.targetX and math.abs(card.x - card.targetX) > 20 then
            return true
        end
        if card.y and card.targetY and math.abs(card.y - card.targetY) > 20 then
            return true
        end
    end
    
    -- Check opponent hand
    for _, card in ipairs(game.opponentHand) do
        if card.moveDelay and card.moveDelay > 0 then
            return true
        end
        -- Check for significant movement (ignore minor hover effects)
        if card.x and card.targetX and math.abs(card.x - card.targetX) > 20 then
            return true
        end
        if card.y and card.targetY and math.abs(card.y - card.targetY) > 20 then
            return true
        end
    end
    
    -- Check cards on the board
    for _, card in ipairs(game.boardCards) do
        if card.moveDelay and card.moveDelay > 0 then
            return true
        end
        -- Check for significant movement (ignore minor hover effects)
        if card.x and card.targetX and math.abs(card.x - card.targetX) > 20 then
            return true
        end
        if card.y and card.targetY and math.abs(card.y - card.targetY) > 20 then
            return true
        end
    end
    
    return false
end

function game_logic.playerStand(game, ui)
    if game.state ~= "player_turn" then
        return
    end
    if #game.playerHand == 0 then
        game.message = game_logic.humanLabel(game) .. " must draw at least one card first."
        return
    end
    
    local isLan = game_logic.isLanMode(game)
    
    if isLan then
        -- In LAN mode: change state and wait for opponent action
        game.state = "dealer_turn"
        
        -- Use turn module to wait for opponent action
        turn.waitForOpponent(game, "action")
        
        -- Sync state
        local lan_mode = require("modes.lan_mode")
        if game.lan.role == "host" then
            lan_mode.sync(game)
        else
            local client = require("lan.client")
            client.sendAction({type = "stand"})
        end
        
        -- Do not run AI logic; wait for network messages to process opponent actions
        return
    else
        -- Local mode: execute AI logic
        game.state = "dealer_turn"
        if game_logic.isHumanBanker(game) then
            game.message = "Idle player is drawing cards..."
            game_logic.aiIdlePlay(game, ui)
        else
            game.message = "Revealing banker hand..."
            revealOpponentHand(game)
        end
        local result, winner, damage = game_logic.evaluateOutcome(game)
        game_logic.concludeRound(game, result, winner, damage, ui)
    end
end

return game_logic

