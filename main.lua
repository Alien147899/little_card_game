-- Main entry file
local lurker = require("libs.lurker")
local config = require("config")
local utils = require("utils")
local card = require("card")
local ui = require("ui")
local game_logic = require("game_logic")
local input = require("input")
local menu = require("scenes.menu")
local table_scene = require("scenes.table")
local lan_scene = require("scenes.lan")
local mode_select = require("scenes.mode_select")
local layout_debugger = require("tools.layout_debugger")
local assets_manager = require("assets_manager")
local shaders = require("shaders")
local local_mode = require("modes.local_mode")
local lan_mode = require("modes.lan_mode")
local profile = require("profile")

local function updateClearAnimation(game, dt)
    local animation = game.clearAnimation
    if not animation or not animation.active then
        return
    end
    animation.elapsed = animation.elapsed + dt
    local moveDuration = animation.moveDuration or 0.35
    local shatterDuration = animation.shatterDuration or 0.35
    local interval = animation.shatterInterval or 0.08
    local allGone = true
    for index, card in ipairs(animation.cards) do
        local startX = card.clearStartX or card.x or 0
        local targetX = card.clearTargetX or -config.CARD.width * 1.5
        local tMove = math.min(1, animation.elapsed / moveDuration)
        card.renderX = startX + (targetX - startX) * tMove
        card.renderY = card.clearStartY or card.y or 0
        card.renderScale = 1
        card.renderAlpha = 1
        local shatterStart = moveDuration + (card.clearDelay or ((index - 1) * interval))
        if animation.elapsed >= shatterStart then
            local localT = math.min(1, (animation.elapsed - shatterStart) / shatterDuration)
            card.renderAlpha = 1 - localT
            card.renderScale = 1 - 0.3 * localT
            if localT < 1 then
                allGone = false
            end
        else
            allGone = false
        end
    end
    if allGone then
        animation.active = false
        game.clearAnimation = nil
        if animation.onComplete then
            animation.onComplete()
        end
    end
end

local game = {
    cardWidth = config.CARD.width,
    cardHeight = config.CARD.height,
    playerHand = {},
    opponentHand = {},
    boardCards = {},
    deck = {},
    draggedCard = nil,
    dragOffsetX = 0,
    dragOffsetY = 0,
    fonts = {},
    zones = {},
    highlightedCard = nil,
    buttons = {},
    menuButtons = {},
    state = "await_start",
    message = "Click \"Start New Round\" to draw cards and decide the banker",
    revealDealer = false,
    maxValue = config.GAME.maxValue,
    screen = "menu",
    mode = "local",
    dealerInitialCount = 0,
    dealerPeekLog = {},
    showTutorial = false,
    tutorialState = 1,
    tutorialMessages = config.TUTORIAL_MESSAGES,
    tutorialLastAdvance = 0,
    maxBankerCards = config.GAME.maxBankerCards,
    humanRole = "idle",
    backgroundImage = nil,
    clearAnimation = nil,
    nextOpponentDealDelay = 0,
    rolesDecided = false,
    roleDraw = nil,
    aiRoundMood = 0,
    aiConfidence = 0,
    aiMemory = {idleCardSamples = 0, idleCardTotal = 0, bankerCardSamples = 0, bankerCardTotal = 0},
    lan = {status = "idle", message = "LAN mode is under development"},
    pauseOverlay = {active = false, buttons = {}},
    modeSelectMessage = "",
}

function love.load()
    love.math.setRandomSeed(os.time())
    profile.load()
    game.profile = profile
    game.fonts.primary = utils.loadFont(config.FONT_PATH, 20)
    game.fonts.button = utils.loadFont(config.FONT_PATH, 18)
    game.fonts.card = utils.loadFont(config.FONT_PATH, 18)
    game.fonts.title = utils.loadFont(config.FONT_PATH, 56)
    game.fonts.info = utils.loadFont(config.FONT_PATH, 18)
    love.graphics.setFont(game.fonts.primary)
    
    -- Load card images
    assets_manager.loadCardImages()
    
    -- Load table background image
    local bgConfig = config.BACKGROUND
    if bgConfig and bgConfig.image and love.filesystem.getInfo(bgConfig.image) then
        game.backgroundImage = love.graphics.newImage(bgConfig.image)
    else
        game.backgroundImage = nil
    end
    
    -- Load menu background image
    local menuBgPath = "assets/macro.jpg"
    if love.filesystem.getInfo(menuBgPath) then
        local success, result = pcall(function()
            return love.graphics.newImage(menuBgPath)
        end)
        if success then
            game.menuBackgroundImage = result
        end
    end
    
    -- Load shader effects
    if config.SHADERS.ENABLED then
        shaders.loadShaders()
        shaders.setEnabled(config.SHADERS.ENABLED)
    end
    
    game.zones = ui.buildZones(game)
    game.deck = card.buildDeck()
    utils.shuffle(game.deck)
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    table_scene.initializeButtons(game)
    table_scene.buildPauseButtons(game)
    menu.initialize(game)
    mode_select.initialize(game)
    lan_scene.initialize(game)
    ui.buildButtons(game)
    ui.buildMenuButtons(game)
    layout_debugger.load()
end

if lurker then
    lurker.postswap = function()
        if love.load then
            love.load()
        end
    end
end

function love.resize(w, h)
    game.zones = ui.buildZones(game)
    ui.layoutHand(game.playerHand, game.zones.playerHand, game)
    ui.layoutHand(game.opponentHand, game.zones.opponentHand, game)
    ui.layoutBoard(game.boardCards, game.zones.playArea)
    ui.buildButtons(game)
    ui.buildMenuButtons(game)
    table_scene.buildPauseButtons(game)
end

function love.update(dt)
    lurker.update()
    updateClearAnimation(game, dt)
    layout_debugger.update(game, dt)
    
    -- Update menu background animation
    if game.screen == "menu" then
        menu.update(dt)
    end
    
    -- LAN network update (required both in lobby and in-game)
    if game.mode == "lan" or game.mode == "lan_game" then
        lan_mode.update(game, dt)
    end
    if game.screen ~= "table" then
        return
    end
    for _, card in ipairs(game.playerHand) do
        ui.updateCardPosition(card, dt)
    end
    for _, card in ipairs(game.boardCards) do
        ui.updateCardPosition(card, dt)
    end
    for _, card in ipairs(game.opponentHand) do
        ui.updateCardPosition(card, dt)
    end
    if game.roleDraw and game.roleDraw.cards then
        for _, card in ipairs(game.roleDraw.cards) do
            ui.updateCardPosition(card, dt)
        end
    end
    game_logic.updateRoleDraw(game, dt)
end

function love.draw()
    -- Menu scene clears background and draws its own background
    if game.screen ~= "menu" then
        love.graphics.clear(0.08, 0.09, 0.12)
    end
    layout_debugger.beginFrame()

    if game.screen == "menu" then
        menu.draw(game)
    elseif game.screen == "lan" then
        lan_scene.draw(game)
    elseif game.screen == "mode_select" then
        mode_select.draw(game)
    else
        table_scene.draw(game)
    end
    layout_debugger.draw(game)
end

function love.mousepressed(x, y, button)
    if layout_debugger.mousepressed(game, x, y, button) then
        return
    end
    if button ~= 1 then
        return
    end
    if game.pauseOverlay and game.pauseOverlay.active then
        if table_scene.handlePauseClick(game, x, y) then
            return
        end
    end
    if game.screen == "menu" then
        menu.handleClick(game, x, y)
        return
    elseif game.screen == "lan" then
        lan_scene.handleClick(game, x, y)
        return
    elseif game.screen == "mode_select" then
        mode_select.handleClick(game, x, y)
        return
    end
    if game.roleDraw and game_logic.handleRoleDrawClick(game, x, y) then
        return
    end
    input.updateHighlightedCard(game, x, y, ui)
    if input.handleButtonClick(game, x, y) then
        return
    end
    local card = input.getDraggableCard(game, x, y)
    if card then
        input.startDrag(game, card, x, y, ui)
    end
end

function love.mousereleased(x, y, button)
    if layout_debugger.mousereleased(game, x, y, button) then
        return
    end
    if button ~= 1 then
        return
    end
    if game.screen ~= "table" then
        return
    end
    if game.pauseOverlay and game.pauseOverlay.active then
        return
    end
    input.finishDrag(game, ui)
end

function love.mousemoved(x, y, dx, dy)
    if layout_debugger.mousemoved(game, x, y, dx, dy) then
        return
    end
    if game.screen ~= "table" then
        return
    end
    if game.pauseOverlay and game.pauseOverlay.active then
        return
    end
    if game.draggedCard then
        game.draggedCard.x = x - game.dragOffsetX
        game.draggedCard.y = y - game.dragOffsetY
        return
    end
    input.updateHighlightedCard(game, x, y, ui)
end

function love.keypressed(key)
    if layout_debugger.keypressed(game, key) then
        return
    end
    if game.screen == "menu" then
        if menu.handleKey(game, key) then
            return
        end
    elseif game.screen == "lan" then
        if lan_scene.handleKey(game, key) then
            return
        end
    elseif game.screen == "mode_select" then
        if mode_select.handleKey(game, key) then
            return
        end
    elseif game.screen == "table" then
        if key == "escape" then
            if game.pauseOverlay and game.pauseOverlay.active then
                table_scene.hidePauseOverlay(game)
            else
                table_scene.showPauseOverlay(game)
            end
            return
        end
    end

    if key == "f11" then
        local isFullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen)
    end
end

function love.textinput(text)
    if game.screen == "menu" then
        if menu.handleTextInput(game, text) then
            return
        end
    elseif game.screen == "lan" then
        if lan_scene.handleTextInput(game, text) then
            return
        end
    end
end

function love.quit()
    print("Game quit")
end
