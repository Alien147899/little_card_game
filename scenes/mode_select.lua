local mode_select = {}

local local_mode = require("modes.local_mode")
local utils = require("utils")
local config = require("config")
local layout_debugger = require("tools.layout_debugger")

local OPTION_WIDTH = 360
local OPTION_HEIGHT = 460
local OPTION_SPACING = 80
local BACK_BUTTON_WIDTH = 200
local BACK_BUTTON_HEIGHT = 56

local function loadImage(path)
    if not path or path == "" or not love.filesystem.getInfo(path) then
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    return ok and img or nil
end

local function buildOptions()
    return {
        {
            id = "ten_point_half",
            label = "Ten and a Half",
            description = "Classic 10.5-point mode using the current rules.",
            imagePath = "cardtable.png",
            action = function(game)
                game.modeSelectMessage = ""
                local_mode.start(game)
            end,
        },
        {
            id = "texas_holdem",
            label = "Texas Hold'em",
            description = "Coming soon: more modes will be added over time.",
            imagePath = "Casino.jpg",
            action = function(game)
                game.modeSelectMessage = "Texas Hold'em mode is under development. Stay tuned."
            end,
        },
    }
end

local function ensureLayout()
    if mode_select.layoutInitialized then
        return
    end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local options = mode_select.options or {}
    local totalWidth = (#options * OPTION_WIDTH) + math.max(0, (#options - 1) * OPTION_SPACING)
    local startX = (w - totalWidth) / 2
    local baseY = h * 0.22
    for index, option in ipairs(options) do
        option.layout = option.layout or {}
        option.layout.x = option.layout.x or (startX + (index - 1) * (OPTION_WIDTH + OPTION_SPACING))
        option.layout.y = option.layout.y or baseY
        option.layout.width = option.layout.width or OPTION_WIDTH
        option.layout.height = option.layout.height or OPTION_HEIGHT
    end
    mode_select.backButton.id = mode_select.backButton.id or "back_button"
    mode_select.backButton.x = mode_select.backButton.x or (w - BACK_BUTTON_WIDTH) / 2
    mode_select.backButton.y = mode_select.backButton.y or (h - 140)
    mode_select.backButton.width = mode_select.backButton.width or BACK_BUTTON_WIDTH
    mode_select.backButton.height = mode_select.backButton.height or BACK_BUTTON_HEIGHT
    mode_select.layoutInitialized = true
end

function mode_select.initialize(game)
    mode_select.options = buildOptions()
    for _, option in ipairs(mode_select.options) do
        option.image = loadImage(option.imagePath)
    end
    mode_select.backButton = {label = "Back to Main Menu"}
    game.modeSelectMessage = ""
    mode_select.fonts = {
        title = utils.loadFont(config.FONT_PATH, 48),
        label = utils.loadFont(config.FONT_PATH, 28),
        description = utils.loadFont(config.FONT_PATH, 18),
        button = utils.loadFont(config.FONT_PATH, 20),
    }
    mode_select.layoutInitialized = false
end

function mode_select.resetLayout()
    mode_select.layoutInitialized = false
    if mode_select.options then
        for _, option in ipairs(mode_select.options) do
            option.layout = nil
        end
    end
    if mode_select.backButton then
        mode_select.backButton.x = nil
        mode_select.backButton.y = nil
        mode_select.backButton.width = nil
        mode_select.backButton.height = nil
    end
end

function mode_select.enter(game)
    game.screen = "mode_select"
    game.state = "mode_select"
    game.modeSelectMessage = ""
end

local function drawOptionCard(option, rect, hovered, fonts)
    local cornerRadius = 18
    local lift = hovered and 12 or 6
    local scale = hovered and 1.04 or 1.0

    love.graphics.push()
    love.graphics.translate(rect.x + rect.width / 2, rect.y + rect.height / 2 - lift)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-rect.width / 2, -rect.height / 2)

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", 4, 6, rect.width, rect.height, cornerRadius + 4, cornerRadius + 4)

    local topColor = hovered and {0.32, 0.48, 0.82} or {0.24, 0.26, 0.42}
    local bottomColor = hovered and {0.12, 0.20, 0.46} or {0.10, 0.14, 0.26}

    local function mixColor(t)
        return {
            topColor[1] * t + bottomColor[1] * (1 - t),
            topColor[2] * t + bottomColor[2] * (1 - t),
            topColor[3] * t + bottomColor[3] * (1 - t),
            0.96,
        }
    end

    for i = 0, 1 do
        local c = mixColor(i)
        love.graphics.setColor(c[1], c[2], c[3], c[4])
        love.graphics.rectangle("fill", 0, i * rect.height / 2, rect.width, rect.height / 2, cornerRadius, cornerRadius)
    end

    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.rectangle("line", 1.5, 1.5, rect.width - 3, rect.height - 3, cornerRadius - 2, cornerRadius - 2)

    if option.image then
        local img = option.image
        local imgScale = math.min((rect.width - 60) / img:getWidth(), (rect.height * 0.55) / img:getHeight())
        local imgX = (rect.width - img:getWidth() * imgScale) / 2
        local imgY = 26
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.draw(img, imgX, imgY, 0, imgScale, imgScale)
    else
        love.graphics.setColor(0.14, 0.18, 0.26, 0.9)
        love.graphics.rectangle("fill", 20, 24, rect.width - 40, rect.height * 0.55, cornerRadius - 6, cornerRadius - 6)
    end

    love.graphics.setColor(0.96, 0.98, 1, 1)
    local labelY = rect.height * 0.65
    love.graphics.setFont(fonts.label)
    love.graphics.printf(option.label, 0, labelY, rect.width, "center")

    love.graphics.setFont(fonts.description)
    love.graphics.setColor(0.85, 0.9, 1, 0.95)
    love.graphics.printf(option.description, 20, labelY + 40, rect.width - 40, "center")

    love.graphics.pop()
end

function mode_select.draw(game)
    ensureLayout()

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.clear(0.07, 0.08, 0.12, 1)

    if game.menuBackgroundImage then
        love.graphics.setColor(1, 1, 1, 0.4)
        local img = game.menuBackgroundImage
        local scale = math.max(w / img:getWidth(), h / img:getHeight())
        local drawX = (w - img:getWidth() * scale) / 2
        local drawY = (h - img:getHeight() * scale) / 2
        love.graphics.draw(img, drawX, drawY, 0, scale, scale)
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local titleY = h * 0.12
    love.graphics.setFont(mode_select.fonts.title)
    love.graphics.setColor(0.96, 0.98, 1, 1)
    love.graphics.printf("Select Game Mode", 0, titleY, w, "center")

    local mx, my = love.mouse.getPosition()
    mode_select.cachedZones = {}

    for _, option in ipairs(mode_select.options or {}) do
        local rect = option.layout or {x = 0, y = 0, width = OPTION_WIDTH, height = OPTION_HEIGHT}
        local hovered = mx >= rect.x and mx <= rect.x + rect.width and my >= rect.y and my <= rect.y + rect.height
        drawOptionCard(option, rect, hovered, mode_select.fonts)
        layout_debugger.registerRect(
            "mode_option:" .. tostring(option.id),
            rect,
            {category = "mode_option", color = {0.4, 0.85, 0.9, 0.35}}
        )
        table.insert(mode_select.cachedZones, {
            x = rect.x,
            y = rect.y,
            width = rect.width,
            height = rect.height,
            action = option.action,
        })
    end

    local btn = mode_select.backButton
    local hovered = mx >= btn.x and mx <= btn.x + btn.width and my >= btn.y and my <= btn.y + btn.height

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", btn.x + 4, btn.y + 6, btn.width, btn.height, 14, 14)
    love.graphics.setColor(0.22, 0.32, 0.56, hovered and 0.98 or 0.78)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 14, 14)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 14, 14)
    love.graphics.setColor(0.96, 0.98, 1, 1)
    love.graphics.setFont(mode_select.fonts.button)
    love.graphics.printf(btn.label, btn.x, btn.y + 16, btn.width, "center")
    layout_debugger.registerRect(
        "mode_button:" .. tostring(btn.id),
        btn,
        {category = "mode_button", color = {0.95, 0.6, 0.3, 0.35}}
    )

    if game.modeSelectMessage and game.modeSelectMessage ~= "" then
        love.graphics.setColor(0.95, 0.78, 0.45, 1)
        love.graphics.setFont(mode_select.fonts.description)
        love.graphics.printf(game.modeSelectMessage, 0, h - 80, w, "center")
    end
end

function mode_select.handleClick(game, x, y)
    for _, zone in ipairs(mode_select.cachedZones or {}) do
        if utils.pointInRect(zone, x, y) then
            if zone.action then
                zone.action(game)
                return true
            end
        end
    end
    local btn = mode_select.backButton
    if btn and utils.pointInRect(btn, x, y) then
        game.screen = "menu"
        game.state = "menu"
        game.modeSelectMessage = ""
        return true
    end
    return false
end

function mode_select.handleKey(game, key)
    if key == "escape" then
        game.screen = "menu"
        game.state = "menu"
        game.modeSelectMessage = ""
        return true
    end
    return false
end

return mode_select
