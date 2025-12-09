-- Resource manager: responsible for loading and managing game assets (images, etc.).
local assets_manager = {}
local config = require("config")

assets_manager.images = {}

-- Convert in-game card info into a card image file name.
local function getCardFileName(suit, rank)
    if config.ASSETS.USE_NEW_CARD_NAMING then
        -- New naming format: {rank}_of_{suit}.png
        local suitMap = {
            spades = "spades",
            hearts = "hearts",
            clubs = "clubs",
            diamonds = "diamonds",
        }

        local rankMap = {
            ["2"] = "2",
            ["3"] = "3",
            ["4"] = "4",
            ["5"] = "5",
            ["6"] = "6",
            ["7"] = "7",
            ["8"] = "8",
            ["9"] = "9",
            ["10"] = "10",
            J = "jack",
            Q = "queen",
            K = "king",
            A = "ace",
        }

        local suitName = suitMap[suit]
        local rankName = rankMap[rank]

        if suitName and rankName then
            return rankName .. "_of_" .. suitName .. ".png"
        end
        return nil
    else
        -- Old naming format: {suit}_{rank}.png
        return suit .. "_" .. rank .. ".png"
    end
end

function assets_manager.loadCardImages()
    -- If using per-card image mode
    if config.ASSETS.USE_INDIVIDUAL_CARDS then
        assets_manager.images.cards = {}
        assets_manager.images.cardsCanvas = {} -- pre-rendered front card canvases

        local suits = { "spades", "hearts", "clubs", "diamonds" }
        local ranks = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A" }

        local baseDir = config.ASSETS.CARD_IMAGE_DIR or "assets/cards"

        for _, suit in ipairs(suits) do
            for _, rank in ipairs(ranks) do
                local fileName = getCardFileName(suit, rank)
                if fileName then
                    local path = baseDir .. "/" .. fileName
                    if love.filesystem.getInfo(path) then
                        local key = suit .. "_" .. rank
                        local originalImage = love.graphics.newImage(path)
                        originalImage:setFilter("linear", "linear")

                        -- Create a high-resolution canvas for the card front (same treatment as back).
                        local canvasWidth = config.CARD.width * 2
                        local canvasHeight = config.CARD.height * 2
                        local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
                        canvas:setFilter("linear", "linear")

                        love.graphics.setCanvas(canvas)
                        -- White background
                        love.graphics.clear(1, 1, 1, 1)

                        -- Crop out any built-in borders from the source image (assume 3–5% border).
                        local imgWidth = originalImage:getWidth()
                        local imgHeight = originalImage:getHeight()

                        -- Define crop region (remove 1.5% margin on each side).
                        local cropPercent = 0.015
                        local cropX = imgWidth * cropPercent
                        local cropY = imgHeight * cropPercent
                        local cropWidth = imgWidth * (1 - cropPercent * 2)
                        local cropHeight = imgHeight * (1 - cropPercent * 2)

                        -- Create a quad for the cropped region.
                        local quad = love.graphics.newQuad(cropX, cropY, cropWidth, cropHeight, imgWidth, imgHeight)

                        -- Scale to fit the canvas with a small margin.
                        local maxWidth = canvasWidth * 0.90
                        local maxHeight = canvasHeight * 0.90
                        local scaleX = maxWidth / cropWidth
                        local scaleY = maxHeight / cropHeight
                        local scale = math.min(scaleX, scaleY)

                        local scaledWidth = cropWidth * scale
                        local scaledHeight = cropHeight * scale
                        local offsetX = (canvasWidth - scaledWidth) / 2
                        local offsetY = (canvasHeight - scaledHeight) / 2

                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(originalImage, quad, offsetX, offsetY, 0, scale, scale)
                        love.graphics.setCanvas()

                        -- Store original image and pre-rendered canvas.
                        assets_manager.images.cards[key] = originalImage
                        assets_manager.images.cardsCanvas[key] = canvas
                    end
                end
            end
        end

        -- Load joker images.
        if config.ASSETS.JOKER_SMALL_IMAGE
            and love.filesystem.getInfo(config.ASSETS.JOKER_SMALL_IMAGE) then
            assets_manager.images.cards["joker_small"] = love.graphics.newImage(config.ASSETS.JOKER_SMALL_IMAGE)
        end
        if config.ASSETS.JOKER_BIG_IMAGE
            and love.filesystem.getInfo(config.ASSETS.JOKER_BIG_IMAGE) then
            assets_manager.images.cards["joker_big"] = love.graphics.newImage(config.ASSETS.JOKER_BIG_IMAGE)
        end

        -- Load card back image (if specified for individual mode).
        if config.ASSETS.CARD_BACK_IMAGE_INDIVIDUAL then
            local path = config.ASSETS.CARD_BACK_IMAGE_INDIVIDUAL
            if love.filesystem.getInfo(path) then
                local originalImage = love.graphics.newImage(path)
                originalImage:setFilter("linear", "linear")

                -- Create a high-resolution canvas for the back with supersampling-like effect.
                local canvasWidth = config.CARD.width * 2
                local canvasHeight = config.CARD.height * 2
                local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
                canvas:setFilter("linear", "linear")

                love.graphics.setCanvas(canvas)
                -- Slightly tinted background to make the reflection look natural.
                love.graphics.clear(0.75, 0.85, 0.40, 1)

                -- Compute centered logo position and scale.
                local imgWidth = originalImage:getWidth()
                local imgHeight = originalImage:getHeight()

                -- Scale logo to fit card size (leave 10% margin).
                local maxWidth = canvasWidth * 0.8
                local maxHeight = canvasHeight * 0.8
                local scaleX = maxWidth / imgWidth
                local scaleY = maxHeight / imgHeight
                local scale = math.min(scaleX, scaleY)

                local scaledWidth = imgWidth * scale
                local scaledHeight = imgHeight * scale
                local offsetX = (canvasWidth - scaledWidth) / 2
                local offsetY = (canvasHeight - scaledHeight) / 2

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(originalImage, offsetX, offsetY, 0, scale, scale)
                love.graphics.setCanvas()

                -- Store back image and canvas.
                assets_manager.images.cardBack = originalImage
                assets_manager.images.cardBackCanvas = canvas
                print("Card back image loaded and pre-rendered successfully (centered): " .. path)
            else
                print("Warning: card back image file not found: " .. path)
            end
        end
    else
        -- Use shared card front/back images.
        local cardFrontPath = config.ASSETS.CARD_FRONT_IMAGE
        if cardFrontPath and love.filesystem.getInfo(cardFrontPath) then
            assets_manager.images.cardFront = love.graphics.newImage(cardFrontPath)
        end

        local cardBackPath = config.ASSETS.CARD_BACK_IMAGE
        if cardBackPath and love.filesystem.getInfo(cardBackPath) then
            assets_manager.images.cardBack = love.graphics.newImage(cardBackPath)
        end
    end
end

function assets_manager.getCardImage(card)
    if not card then
        return nil
    end

    -- If the card is face down, always return the back image when available.
    if card.faceDown then
        if config.ASSETS.USE_INDIVIDUAL_CARDS and assets_manager.images.cardBack then
            return assets_manager.images.cardBack
        end
        if assets_manager.images.cardBack then
            return assets_manager.images.cardBack
        end
        return nil
    end

    -- In individual card mode, return a pre-rendered canvas or image for the card front when available.
    if config.ASSETS.USE_INDIVIDUAL_CARDS then
        -- Default key is the card ID (e.g. "joker_small", "joker_big").
        local key = card.id
        -- For normal suit cards, use "{suit}_{rank}" to match the loaded image keys.
        if card.suit and card.rank and card.suit ~= "joker" then
            key = card.suit .. "_" .. card.rank
        end

        -- Prefer pre-rendered canvas (scaled and centered).
        if assets_manager.images.cardsCanvas and assets_manager.images.cardsCanvas[key] then
            return assets_manager.images.cardsCanvas[key]
        end

        -- Fallback to original image.
        if assets_manager.images.cards and assets_manager.images.cards[key] then
            return assets_manager.images.cards[key]
        end
    end

    -- Otherwise use shared front image.
    if assets_manager.images.cardFront then
        return assets_manager.images.cardFront
    end

    return nil
end

function assets_manager.hasImages()
    return assets_manager.images.cardFront ~= nil or assets_manager.images.cardBack ~= nil
end

return assets_manager
