-- Menu background card-fall animation
local menuBg = {}
local config = require("config")
local assets_manager = require("assets_manager")
local roundedFrontCache = {}
local roundedBackTexture = nil
local drawFallingCard

-- List of falling card particles
menuBg.fallingCards = {}

-- Configuration
local CARD_COUNT = 18  -- Number of cards falling at the same time
local FALL_SPEED_MIN = 60  -- Minimum fall speed (pixels/second)
local FALL_SPEED_MAX = 160  -- Maximum fall speed
local ROTATION_SPEED_MIN = -0.9  -- Minimum rotation speed (radians/second)
local ROTATION_SPEED_MAX = 0.9   -- Maximum rotation speed
local SPAWN_INTERVAL = 0.5  -- Interval for spawning new cards (seconds)

-- All possible card types used in the background
local CARD_TYPES = {
    {suit = "spades", rank = "A"},
    {suit = "hearts", rank = "K"},
    {suit = "diamonds", rank = "Q"},
    {suit = "clubs", rank = "J"},
    {suit = "spades", rank = "10"},
    {suit = "hearts", rank = "9"},
    {suit = "diamonds", rank = "7"},
    {suit = "clubs", rank = "5"},
    {suit = "spades", rank = "3"},
    {suit = "hearts", rank = "2"},
}

-- Initialize background animation
function menuBg.init()
    menuBg.fallingCards = {}
    menuBg.lastSpawnTime = 0
    menuBg.spawnTimer = 0
    
    -- Spawn initial cards immediately, distributed across full screen height
    local screenHeight = love.graphics.getHeight()
    for i = 1, CARD_COUNT do
        local card = createInitialCard(i, CARD_COUNT, screenHeight)
        table.insert(menuBg.fallingCards, card)
    end
end

-- Create an initial card (distributed across the whole screen on startup)
function createInitialCard(index, total, screenHeight)
    local screenWidth = love.graphics.getWidth()
    local cardType = CARD_TYPES[love.math.random(1, #CARD_TYPES)]
    local isFaceUp = love.math.random() > 0.5
    
    -- Distribute cards across the entire screen height instead of only at the top
    local yPosition = (index / total) * (screenHeight + config.CARD.height * 2) - config.CARD.height
    
    -- Random depth (simulate near/far perspective)
    local depth = love.math.random(35, 130) / 100  -- 0.35 to 1.3
    
    return {
        x = love.math.random(-50, screenWidth + 50),
        y = yPosition,
        rotation = love.math.random() * math.pi * 2,
        rotationSpeed = love.math.random() * (ROTATION_SPEED_MAX - ROTATION_SPEED_MIN) + ROTATION_SPEED_MIN,
        fallSpeed = (love.math.random() * (FALL_SPEED_MAX - FALL_SPEED_MIN) + FALL_SPEED_MIN) * depth,
        alpha = 1.0,
        scale = 0.6 + depth * 1.0,  -- Larger when closer, can be >1
        depth = depth,  -- Save depth for sorting
        suit = cardType.suit,
        rank = cardType.rank,
        isFaceUp = isFaceUp,
    }
end

-- Spawn a new falling card
local function spawnCard()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Randomly choose a card type
    local cardType = CARD_TYPES[love.math.random(1, #CARD_TYPES)]
    
    -- Randomly choose face-up or back
    local isFaceUp = love.math.random() > 0.5
    
    -- Random depth: larger depth means card appears "farther", with slower speed
    local depth = love.math.random(35, 130) / 100  -- 0.35 to 1.3
    
    local card = {
        x = love.math.random(-100, screenWidth + 100),  -- Random position across screen width
        y = -config.CARD.height - 50,  -- Spawn above the top of the screen
        rotation = love.math.random() * math.pi * 2,  -- Random initial rotation
        rotationSpeed = love.math.random() * (ROTATION_SPEED_MAX - ROTATION_SPEED_MIN) + ROTATION_SPEED_MIN,
        fallSpeed = (love.math.random() * (FALL_SPEED_MAX - FALL_SPEED_MIN) + FALL_SPEED_MIN) * depth,  -- Depth-influenced speed
        alpha = 1.0,  -- Fully opaque so cards occlude each other
        scale = 0.6 + depth * 1.0,  -- Larger when closer, can be >1
        depth = depth,  -- Save depth for sorting
        suit = cardType.suit,
        rank = cardType.rank,
        isFaceUp = isFaceUp,
    }
    
    table.insert(menuBg.fallingCards, card)
end

-- Update background animation
function menuBg.update(dt)
    -- Periodically spawn new cards
    menuBg.spawnTimer = menuBg.spawnTimer + dt
    if menuBg.spawnTimer >= SPAWN_INTERVAL then
        menuBg.spawnTimer = menuBg.spawnTimer - SPAWN_INTERVAL
        
        -- If there are too few cards, spawn a new one
        if #menuBg.fallingCards < CARD_COUNT then
            spawnCard()
        end
    end
    
    local screenHeight = love.graphics.getHeight()
    
    -- Update each card's position and rotation
    for i = #menuBg.fallingCards, 1, -1 do
        local card = menuBg.fallingCards[i]
        
        -- Update position
        card.y = card.y + card.fallSpeed * dt
        
        -- Update rotation
        card.rotation = card.rotation + card.rotationSpeed * dt
        
        -- Remove card if it falls off screen
        if card.y > screenHeight + config.CARD.height + 50 then
            table.remove(menuBg.fallingCards, i)
        end
    end
end

-- Draw the background animation
function menuBg.draw()
    -- Do not draw a dark background; menu.draw() already handles it
    
    -- Sort by depth so farther cards are drawn first
    local sortedCards = {}
    for _, card in ipairs(menuBg.fallingCards) do
        table.insert(sortedCards, card)
    end
    table.sort(sortedCards, function(a, b)
        return a.depth < b.depth  -- Smaller depth (farther) drawn first
    end)
    
    -- Draw sorted cards
    for _, card in ipairs(sortedCards) do
        drawFallingCard(card)
    end
end

local function drawCardOutline(cornerRadius, cardWidth, cardHeight)
    local outlineConfig = config.CARD_OUTLINE or {}
    if not outlineConfig.enabled then
        return
    end
    local color = outlineConfig.color or {0, 0, 0, 0.6}
    local previousLineWidth = love.graphics.getLineWidth()
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.6)
    love.graphics.setLineWidth(outlineConfig.width or 2)
    love.graphics.rectangle("line", -cardWidth / 2, -cardHeight / 2, cardWidth, cardHeight, cornerRadius, cornerRadius)
    love.graphics.setLineWidth(previousLineWidth)
end

drawFallingCard = function(card)
    love.graphics.push()
    love.graphics.translate(card.x, card.y)
    love.graphics.rotate(card.rotation)
    love.graphics.scale(card.scale, card.scale)
    
    local cardWidth = config.CARD.width
    local cardHeight = config.CARD.height
    local cornerRadius = config.CARD_CORNER_RADIUS or 12

    -- Use stencil to apply rounded-rectangle clipping, matching in-game cards
    local function stencilFunc()
        love.graphics.rectangle(
            "fill",
            -cardWidth / 2,
            -cardHeight / 2,
            cardWidth,
            cardHeight,
            cornerRadius,
            cornerRadius
        )
    end

    love.graphics.stencil(stencilFunc, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    if card.isFaceUp then
        -- Front side: use pre-rendered front canvas (same cardsCanvas as in the game table)
        local key = card.suit .. "_" .. card.rank
        local cardCanvas = assets_manager.images.cardsCanvas and assets_manager.images.cardsCanvas[key]
        if cardCanvas then
            love.graphics.setColor(1, 1, 1, 1)
            -- Pre-rendered at 2x resolution; scale down by 0.5 as in ui.lua
            local scale = 0.5
            love.graphics.draw(cardCanvas, -cardWidth / 2, -cardHeight / 2, 0, scale, scale)
        end
    else
        -- Back side: use the same cardBackCanvas as in the game table
        local backCanvas = assets_manager.images.cardBackCanvas
        if backCanvas then
            love.graphics.setColor(1, 1, 1, 1)
            local scale = 0.5
            love.graphics.draw(backCanvas, -cardWidth / 2, -cardHeight / 2, 0, scale, scale)
        end
    end

    love.graphics.setStencilTest()

    -- Outer black outline (matching CARD_OUTLINE used in the game)
    drawCardOutline(cornerRadius, cardWidth, cardHeight)

    love.graphics.pop()
end

return menuBg

