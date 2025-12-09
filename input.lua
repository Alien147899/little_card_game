-- Input handling and drag logic
local input = {}
local utils = require("utils")
local config = require("config")
local ui = require("ui")

local function affectsHandLayout(card)
    return card and (card.container == "playerHand" or card.container == "opponentHand")
end

function input.getCardAt(hand, x, y)
    for i = #hand, 1, -1 do
        local card = hand[i]
        if x >= card.x and x <= card.x + config.CARD.width and y >= card.y and y <= card.y + config.CARD.height then
            return card
        end
    end
    return nil
end

function input.getDraggableCard(game, x, y)
    local card = input.getCardAt(game.boardCards, x, y)
    if card and card.draggable then
        return card
    end
    card = input.getCardAt(game.playerHand, x, y)
    if card and card.draggable then
        return card
    end
    return nil
end

function input.setHighlightedCard(game, card, ui)
    if game.highlightedCard == card then
        return
    end
    local previous = game.highlightedCard
    game.highlightedCard = card
    if affectsHandLayout(previous) or affectsHandLayout(card) then
        ui.layoutHand(game.playerHand, game.zones.playerHand, game)
        ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    end
end

function input.updateHighlightedCard(game, x, y, ui)
    if game.draggedCard then
        return
    end
    local hoverConfig = config.HOVER_EFFECT or {}
    local allowPlayer = hoverConfig.applyToPlayerHand ~= false
    local allowOpponent = hoverConfig.applyToOpponentHand
    local card = nil
    if game.roleDraw and game.roleDraw.cards then
        card = input.getCardAt(game.roleDraw.cards, x, y)
    end
    if allowPlayer then
        if not card then
            card = input.getCardAt(game.playerHand, x, y)
        end
    end
    if not card and allowOpponent then
        card = input.getCardAt(game.opponentHand, x, y)
    end
    input.setHighlightedCard(game, card, ui)
end

function input.calculateHandInsertIndex(game, card)
    local zone = game.zones.playerHand
    if not zone then
        return #game.playerHand + 1
    end
    local centerX = card.x + config.CARD.width / 2
    centerX = math.max(zone.x, math.min(centerX, zone.x + zone.width))
    local index = 1
    for i, existing in ipairs(game.playerHand) do
        local existingCenter = (existing.isDragging and existing.x or existing.targetX) + config.CARD.width / 2
        if centerX > existingCenter then
            index = i + 1
        else
            break
        end
    end
    return index
end

function input.attachCardToPlayerHand(game, card, insertIndex, ui)
    local wasOnBoard = utils.removeCardFromList(game.boardCards, card)
    utils.removeCardFromList(game.playerHand, card)
    if insertIndex then
        table.insert(game.playerHand, insertIndex, card)
    else
        table.insert(game.playerHand, card)
    end
    card.container = "playerHand"
    card.faceDown = false
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    if wasOnBoard then
        ui.layoutBoard(game.boardCards, game.zones.playArea)
    end
end

function input.startDrag(game, card, x, y, ui)
    game.highlightedCard = nil
    game.draggedCard = card
    card.isDragging = true
    card.dragOrigin = card.container
    if card.container == "playerHand" then
        local removed = utils.removeCardFromList(game.playerHand, card)
        if removed then
            ui.layoutHand(game.playerHand, game.zones.playerHand, game)
        end
    end
    game.dragOffsetX = x - card.x
    game.dragOffsetY = y - card.y
end

function input.finishDrag(game, ui)
    local card = game.draggedCard
    if not card then
        return
    end
    card.isDragging = false
    game.draggedCard = nil
    local insertIndex = input.calculateHandInsertIndex(game, card)
    input.attachCardToPlayerHand(game, card, insertIndex, ui)
end

function input.handleButtonClick(game, x, y)
    for _, btn in ipairs(game.buttons) do
        if btn.visibleStates and btn.visibleStates[game.state] then
            if utils.pointInRect(btn, x, y) then
                if btn.action then
                    btn.action()
                end
                return true
            end
        end
    end
    return false
end

return input

