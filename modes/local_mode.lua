local card_module = require("card")
local utils = require("utils")

local local_mode = {}

local function defaultMessage()
    return "Click \"Start New Round\" to draw cards and decide the banker"
end

local function resetGameState(game, opts)
    opts = opts or {}
    game.mode = "local"
    game.state = "await_start"
    game.message = opts.message or defaultMessage()
    game.humanRole = "idle"
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
    game.pauseOverlay = game.pauseOverlay or {active = false, buttons = {}}
    game.pauseOverlay.active = false
    if opts.screen then
        game.screen = opts.screen
    end
end

function local_mode.start(game)
    resetGameState(game, {screen = "table"})
end

function local_mode.returnToMenu(game)
    resetGameState(game, {screen = "menu"})
end

function local_mode.ensureMessage(game)
    game.message = defaultMessage()
end

return local_mode


