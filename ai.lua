-- AI opponent logic module
-- Contains AI decision making, behavior patterns, and memory system.

local ai = {}
local config = require("config")
local card_module = require("card")

-- ============================================================================
-- Utility functions
-- ============================================================================

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local function getAiBehaviorSection(section)
    local cfg = config.AI_BEHAVIOR or {}
    return cfg[section] or {}
end

-- Expose behavior section helper for external use
function ai.getAiBehaviorSection(section)
    return getAiBehaviorSection(section)
end

-- ============================================================================
-- AI memory system
-- Records human behavior across rounds to adjust AI strategy
-- ============================================================================

-- Get the human player's average card count when playing as idle
local function getHumanIdleAverage(game)
    local memory = game.aiMemory
    if not memory or (memory.idleCardSamples or 0) == 0 then
        return nil
    end
    return (memory.idleCardTotal or 0) / memory.idleCardSamples
end

-- Record human draw statistics for this game (for AI "learning")
function ai.recordHumanCardStats(game)
    local memory = game.aiMemory
    if not memory then
        return
    end

    local count = #game.playerHand
    if count <= 0 then
        return
    end

    local game_logic = require("game_logic")
    if game_logic.isHumanBanker(game) then
        memory.bankerCardSamples = (memory.bankerCardSamples or 0) + 1
        memory.bankerCardTotal = (memory.bankerCardTotal or 0) + count
    else
        memory.idleCardSamples = (memory.idleCardSamples or 0) + 1
        memory.idleCardTotal = (memory.idleCardTotal or 0) + count
    end
end

-- ============================================================================
-- AI mood / aggression computation
-- ============================================================================

-- Compute the current aggression index for the AI
-- Based on mood, confidence, life difference, win difference, player hand size, etc.
function ai.computeAggression(game, role)
    local pressure = getAiBehaviorSection("pressure")
    local aggression = (game.aiRoundMood or 0) + (game.aiConfidence or 0)

    -- Life and hand-size based adjustment
    -- Idle AI: adjust based on the human's current hand size
    if role == "idle" then
        local reference = pressure.cardCountReference or 2.5
        aggression = aggression + (#game.playerHand - reference) * (pressure.cardCountWeight or 0)

    -- Banker AI: adjust based on human's historical average hand size as idle
    elseif role == "banker" then
        local avgIdle = getHumanIdleAverage(game)
        if avgIdle then
            local ref = pressure.idleAvgReference or 3.0
            aggression = aggression + (avgIdle - ref) * (pressure.idleAvgWeight or 0.02)
        end
    end

    local clampValue = pressure.clamp or 0.35
    return clamp(aggression, -clampValue, clampValue)
end

-- ============================================================================
-- AI decision logic - banker (dealer)
-- ============================================================================

-- Decide whether the banker AI should continue drawing cards
function ai.dealerShouldContinue(currentValue, game)
    if currentValue >= game.maxValue then
        return false
    end

    local behavior = getAiBehaviorSection("dealer")
    local aggression = ai.computeAggression(game, "banker")

    -- Safe zone: must hit
    local safeHit = (behavior.forceHitBelow or 6.5)
        + aggression * (behavior.safeHitAggression or 0.8)
    if currentValue <= safeHit then
        return true
    end

    -- Danger zone: must stand
    local stopValue = (behavior.forceStopAbove or 9.6)
        + aggression * (behavior.stopAggression or 0.6)
    if currentValue >= stopValue then
        return false
    end

    -- Middle zone: random decision, influenced by aggression
    local chance = (behavior.randomHitChance or 0.45)
        + aggression * (behavior.chanceAggression or 0.25)
    chance = clamp(chance, 0.05, 0.95)
    return love.math.random() < chance
end

-- Initial draw phase for banker AI (automatically draws based on strategy)
function ai.dealerInitialDraw(game, ui, dealCardFunc)
    game.dealerInitialCount = 0
    game.dealerPeekLog = {}

    game.nextOpponentDealDelay = 0
    while game.dealerInitialCount < game.maxBankerCards do
        local card = dealCardFunc(game, "dealer", ui)
        if not card then
            return false
        end

        game.dealerInitialCount = game.dealerInitialCount + 1
        table.insert(game.dealerPeekLog, card.label)

        local value = select(1, card_module.evaluateHand(game.opponentHand))
        if not ai.dealerShouldContinue(value, game) then
            break
        end
    end

    -- Ensure at least one card is drawn
    game.nextOpponentDealDelay = 0
    if game.dealerInitialCount == 0 then
        local card = dealCardFunc(game, "dealer", ui)
        if not card then
            return false
        end
        game.dealerInitialCount = 1
        table.insert(game.dealerPeekLog, card.label)
    end

    return true
end

-- ============================================================================
-- AI decision logic - idle player
-- ============================================================================

-- Decide whether the idle AI should continue drawing cards
function ai.idleShouldContinue(currentValue, game)
    if currentValue >= config.GAME.maxValue then
        return false
    end

    local behavior = getAiBehaviorSection("idle")
    local aggression = ai.computeAggression(game, "idle")

    -- Safe zone: must hit
    local safeHit = (behavior.forceHitBelow or 7.4)
        + aggression * (behavior.safeHitAggression or 0.7)
    if currentValue <= safeHit then
        return true
    end

    -- Danger zone: must stand
    local stopValue = (behavior.forceStopAbove or 9.8)
        + aggression * (behavior.stopAggression or 0.7)
    if currentValue >= stopValue then
        return false
    end

    -- Middle zone: random decision, influenced by aggression
    local chance = (behavior.randomHitChance or 0.4)
        + aggression * (behavior.chanceAggression or 0.3)
    chance = clamp(chance, 0.05, 0.95)
    return love.math.random() < chance
end

-- Idle AI play phase (automatically draws based on strategy)
function ai.idlePlay(game, ui, dealCardFunc, ensureDeckFunc)
    local drew = 0
    game.nextOpponentDealDelay = 0

    while true do
        ensureDeckFunc(game, 1)
        local card = dealCardFunc(game, "dealer", ui)
        if not card then
            break
        end
        drew = drew + 1

        local value = select(1, card_module.evaluateHand(game.opponentHand))
        if value > config.GAME.maxValue then
            break
        end
        if drew >= 1 and not ai.idleShouldContinue(value, game) then
            break
        end
    end

    -- Ensure at least one card is drawn
    game.nextOpponentDealDelay = 0
    if drew == 0 then
        ensureDeckFunc(game, 1)
        dealCardFunc(game, "dealer", ui)
    end
end

-- ============================================================================
-- Module export
-- ============================================================================

return ai

