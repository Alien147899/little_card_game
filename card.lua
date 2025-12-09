-- Card-related logic.
local card = {}
local utils = require("utils")
local config = require("config")

function card.cardNumericValue(rank)
    if rank == "A" then
        return 1
    end
    if rank == "J" or rank == "Q" or rank == "K" then
        return 0.5
    end
    local numeric = tonumber(rank)
    if numeric then
        return numeric
    end
    return 0.5
end

function card.buildDeck()
    local suits = {
        { name = "spades", short = "♠", color = { 0.18, 0.2, 0.28 }, textColor = { 0.1, 0.1, 0.12 } },
        { name = "hearts", short = "♥", color = { 0.7, 0.22, 0.28 }, textColor = { 0.92, 0.86, 0.86 } },
        { name = "clubs", short = "♣", color = { 0.2, 0.32, 0.24 }, textColor = { 0.1, 0.15, 0.1 } },
        { name = "diamonds", short = "♦", color = { 0.78, 0.35, 0.2 }, textColor = { 0.95, 0.88, 0.84 } },
    }
    local ranks = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A" }
    local deck = {}

    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            local label = suit.short .. rank
            table.insert(deck, {
                id = suit.name .. "_" .. rank,
                label = label,
                suit = suit.name,
                rank = rank,
                color = utils.shallowCopy(suit.color),
                textColor = utils.shallowCopy(suit.textColor),
                value = card.cardNumericValue(rank),
                owner = "deck",
                container = "deck",
                draggable = false,
                faceDown = true,
                x = 0,
                y = 0,
                targetX = 0,
                targetY = 0,
            })
        end
    end

    local jokers = {
        { id = "joker_small", label = "Small Joker", color = { 0.3, 0.3, 0.3 }, textColor = { 0.9, 0.9, 0.9 } },
        { id = "joker_big", label = "Big Joker", color = { 0.9, 0.45, 0.15 }, textColor = { 0.1, 0.05, 0.05 } },
    }

    for _, joker in ipairs(jokers) do
        table.insert(deck, {
            id = joker.id,
            label = joker.label,
            suit = "joker",
            rank = joker.label,
            color = utils.shallowCopy(joker.color),
            textColor = utils.shallowCopy(joker.textColor),
            value = 0.5,
            owner = "deck",
            container = "deck",
            draggable = false,
            faceDown = true,
            x = 0,
            y = 0,
            targetX = 0,
            targetY = 0,
        })
    end

    return deck
end

function card.evaluateHand(hand)
    local total = 0
    for _, c in ipairs(hand) do
        total = total + (c.value or 0)
    end
    return total, #hand
end

function card.formatValue(value)
    return string.format("%.1f", value)
end

return card

