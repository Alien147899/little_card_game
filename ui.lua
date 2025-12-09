-- UI rendering and layout
local ui = {}
local config = require("config")
local layout_debugger = require("tools.layout_debugger")

local function updateCardFlipState(card, dt)
    if not card or not card.isFlipping then
        return
    end
    card.flipElapsed = (card.flipElapsed or 0) + dt
    local duration = card.flipDuration or 0.45
    if not card.flipSwapped and card.flipTargetFaceDown ~= nil and card.flipElapsed >= duration * 0.5 then
        card.faceDown = card.flipTargetFaceDown
        card.flipSwapped = true
    end
    if card.flipElapsed >= duration then
        card.isFlipping = false
        card.flipElapsed = nil
        card.flipTargetFaceDown = nil
        card.flipSwapped = nil
    end
end

function ui.buildZones(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local padding = 40
    local handHeight = 140
    local opponentHeight = 140
    local zoneWidth = (w - padding * 2) / 2
    local centeredX = padding + (w - padding * 2 - zoneWidth) / 2
    local deckX = w - padding - config.CARD.width
    local deckY = (h / 2) - (config.CARD.height / 2)
    local opponentOffsetY = 50

    return {
        opponentHand = {
            id = "opponentHand",
            label = "Opponent hand zone",
            x = centeredX,
            y = padding + opponentOffsetY,
            width = zoneWidth,
            height = opponentHeight,
            color = {0.15, 0.12, 0.18},
        },
        playerHand = {
            id = "playerHand",
            label = "Your hand zone",
            x = centeredX,
            y = h - padding - handHeight - 120,
            width = zoneWidth,
            height = handHeight,
            color = {0.12, 0.16, 0.22},
        },
        drawPile = {
            id = "drawPile",
            label = "Deck",
            x = deckX,
            y = deckY,
            width = config.CARD.width,
            height = config.CARD.height,
            color = {0.2, 0.2, 0.28},
        },
    }
end

function ui.layoutHand(hand, zone, game)
    if not zone then
        return
    end
    local count = #hand
    if count == 0 then
        return
    end
    local spacing = 0
    if count > 1 then
        local maxWidth = math.max(8, zone.width - config.CARD.width)
        spacing = math.min(36, maxWidth / (count - 1))
    end
    local totalWidth = config.CARD.width + spacing * (count - 1)
    local startX = zone.x + math.max(0, (zone.width - totalWidth) / 2)
    local baseY = zone.y + zone.height - config.CARD.height - 12
    local hoverEffect = config.HOVER_EFFECT or {}
    local highlightLift = hoverEffect.layoutLift or 28
    local allowPlayer = hoverEffect.applyToPlayerHand ~= false
    local allowOpponent = hoverEffect.applyToOpponentHand
    for i, card in ipairs(hand) do
        if not card.isDragging then
            card.targetX = startX + (i - 1) * spacing
            local lift = 0
            if hoverEffect.enabled and card == game.highlightedCard then
                if zone.id == "playerHand" and allowPlayer then
                    lift = highlightLift
                elseif zone.id == "opponentHand" and allowOpponent then
                    lift = highlightLift
                end
            end
            card.targetY = baseY - lift
        end
        card.container = zone.id
    end
end

function ui.layoutBoard(boardCards, zone)
    if not zone then
        return
    end
    local count = #boardCards
    if count == 0 then
        return
    end
    local spacing = 24
    local totalWidth = (count * config.CARD.width) + ((count - 1) * spacing)
    local startX = zone.x + math.max(0, (zone.width - totalWidth) / 2)
    local targetY = zone.y + zone.height / 2 - config.CARD.height / 2
    for i, card in ipairs(boardCards) do
        if not card.isDragging then
            card.targetX = startX + (i - 1) * (config.CARD.width + spacing)
            card.targetY = targetY
        end
        card.container = "board"
    end
end

function ui.drawCard(card, game, mouseX, mouseY, time)
    local assets_manager = require("assets_manager")
    local shaders = require("shaders")

    -- Decide whether this frame should render the card face down based on its position
    local renderFaceDown = card.faceDown
    if not renderFaceDown and game and game.zones and game.zones.drawPile then
        local dz = game.zones.drawPile
        local cx = card.x or 0
        local cy = card.y or 0
        
        if cx >= dz.x and cx <= dz.x + dz.width
           and cy >= dz.y and cy <= dz.y + dz.height then
            renderFaceDown = true
        end
    end

    -- Choose texture based on renderFaceDown
    local cardImage
    if renderFaceDown and assets_manager.images and assets_manager.images.cardBackCanvas then
        -- For the back side, prefer using the pre-rendered Canvas
        cardImage = assets_manager.images.cardBackCanvas
    else
        -- For the front side or when there is no Canvas, use the generic logic
        cardImage = assets_manager.getCardImage(card)
    end

    local isHighlighted = card == game.highlightedCard
    local isDragging = card == game.draggedCard
    local hoverEffect = config.HOVER_EFFECT or {}
    local shadowConfig = config.CARD_SHADOW or {}
    local canHoverPlayer = hoverEffect.applyToPlayerHand ~= false
    local canHoverOpponent = hoverEffect.applyToOpponentHand
    local container = card.container
    local isRoleDrawCard = container == "role_draw"
    local applyHoverEffect = false
    if hoverEffect.enabled and isHighlighted then
        if container == "playerHand" and canHoverPlayer then
            applyHoverEffect = true
        elseif container == "opponentHand" and canHoverOpponent then
            applyHoverEffect = true
        elseif isRoleDrawCard then
            applyHoverEffect = true
        end
    end
    if card.disableHoverEffect then
        applyHoverEffect = false
    end
    if isRoleDrawCard and game.roleDraw and game.roleDraw.stage ~= "await_player" then
        applyHoverEffect = false
    end
    local renderAlpha = card.renderAlpha or 1
    local function applyColor(r, g, b, a)
        love.graphics.setColor(r, g, b, (a or 1) * renderAlpha)
    end
    
    -- Apply shader effects (set before drawing)
    local shaderApplied = false
    if config.SHADERS.ENABLED then
        -- Apply glow effect (mouse hover)
        if applyHoverEffect and config.SHADERS.GLOW.enabled and mouseX and mouseY then
            shaders.applyGlowEffect(card, game, mouseX, mouseY)
            shaderApplied = true
        end
        
        -- Apply aura effect (highlighted card)
        if applyHoverEffect and config.SHADERS.AURA.enabled and time then
            shaders.applyAuraEffect(card, time, 
                config.SHADERS.AURA.intensity,
                config.SHADERS.AURA.speed,
                config.SHADERS.AURA.color1,
                config.SHADERS.AURA.color2)
            shaderApplied = true
        end
        
        -- Apply sparkle particle effect (dragging card)
        if isDragging and config.SHADERS.SPARKLE.enabled and time then
            shaders.applySparkleEffect(card, time,
                config.SHADERS.SPARKLE.intensity,
                config.SHADERS.SPARKLE.speed,
                config.SHADERS.SPARKLE.count)
            shaderApplied = true
        end
    end
    
    local baseX = card.renderX or card.x or 0
    local baseY = card.renderY or card.y or 0
    local extraLift = applyHoverEffect and (hoverEffect.extraLift or 0) or 0
    local wobbleOffsetY = 0
    local wobbleOffsetX = 0
    local currentTime = time or love.timer.getTime()

    if hoverEffect.enabled and not card.disableIdleWobble then
        -- Default vertical wobble (also active when not selected)
        local idleAmp = hoverEffect.idleWobbleAmplitude or 0
        if idleAmp ~= 0 then
            card._idlePhase = card._idlePhase or love.math.random() * math.pi * 2
            local idleSpeed = hoverEffect.idleWobbleSpeed or 1.2
            wobbleOffsetY = wobbleOffsetY + math.sin(currentTime * idleSpeed + card._idlePhase) * idleAmp
        end
        local idleAmpX = hoverEffect.idleWobbleHorizontalAmplitude or 0
        if idleAmpX ~= 0 then
            card._idlePhaseHoriz = card._idlePhaseHoriz or love.math.random() * math.pi * 2
            local idleSpeedX = hoverEffect.idleWobbleHorizontalSpeed or hoverEffect.idleWobbleSpeed or 1.2
            wobbleOffsetX = wobbleOffsetX + math.sin(currentTime * idleSpeedX + card._idlePhaseHoriz) * idleAmpX
        end
    end

    if applyHoverEffect then
        local ampY = hoverEffect.wobbleAmplitude or 0
        if ampY ~= 0 then
            card._hoverPhaseY = card._hoverPhaseY or love.math.random() * math.pi * 2
            local speedY = hoverEffect.wobbleSpeed or 2
            wobbleOffsetY = wobbleOffsetY + math.sin(currentTime * speedY + card._hoverPhaseY) * ampY
        end

        local ampX = hoverEffect.wobbleHorizontalAmplitude or 0
        if ampX ~= 0 then
            card._hoverPhaseX = card._hoverPhaseX or love.math.random() * math.pi * 2
            local speedX = hoverEffect.wobbleHorizontalSpeed or (hoverEffect.wobbleSpeed or 2)
            wobbleOffsetX = wobbleOffsetX + math.sin(currentTime * speedX + card._hoverPhaseX) * ampX
        end
    end
    -- Compute final position with wobble offset (smooth motion using high-resolution Canvas to reduce jitter)
    local drawX = baseX + wobbleOffsetX
    local drawY = baseY - extraLift + wobbleOffsetY
    
    -- Estimate tilt vector based on wobble offset for the card-back reflection shader
    local maxTiltX = (hoverEffect.wobbleHorizontalAmplitude or 0) + (hoverEffect.idleWobbleHorizontalAmplitude or 0)
    local maxTiltY = (hoverEffect.wobbleAmplitude or 0) + (hoverEffect.idleWobbleAmplitude or 0)
    local tiltX, tiltY = 0, 0
    if maxTiltX > 0 then
        tiltX = math.max(-1, math.min(1, wobbleOffsetX / maxTiltX))
    end
    if maxTiltY > 0 then
        tiltY = math.max(-1, math.min(1, wobbleOffsetY / maxTiltY))
    end
    
    local scale = applyHoverEffect and (hoverEffect.scale or 1.05) or 1
    if card.renderScale then
        scale = card.renderScale
    end

    local function drawCardContents()
        local cornerRadius = config.CARD_CORNER_RADIUS or 12

        -- Define stencil function for rounded-rectangle clipping
        local function stencilFunc()
            love.graphics.rectangle("fill", 0, 0, config.CARD.width, config.CARD.height, cornerRadius, cornerRadius)
        end

        -- Enable stencil so drawing happens only inside the rounded rectangle
        love.graphics.stencil(stencilFunc, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        if cardImage then
            applyColor(1, 1, 1, 1)
            
            local assets_manager = require("assets_manager")
            
            -- Check whether this is a pre-rendered Canvas (2x resolution)
            local isCanvas = cardImage and cardImage.typeOf and cardImage:typeOf("Canvas")
            local isHighRes = isCanvas and cardImage:getWidth() == config.CARD.width * 2
            
            if renderFaceDown and assets_manager.images.cardBackCanvas then
                -- Card back: use the reflection shader and adjust lighting with tiltX/tiltY
                local canvas = assets_manager.images.cardBackCanvas
                local currentTime = time or love.timer.getTime()
                if config.SHADERS.ENABLED and shaders.applyCardBackStable(canvas:getWidth(), canvas:getHeight(), currentTime, tiltX, tiltY) then
                    love.graphics.draw(canvas, 0, 0, 0, 0.5, 0.5)
                    shaders.resetShader()
                else
                    love.graphics.draw(canvas, 0, 0, 0, 0.5, 0.5)
                end
            elseif isHighRes then
                -- Front card (pre-rendered Canvas): draw scaled down
                love.graphics.draw(cardImage, 0, 0, 0, 0.5, 0.5)
            elseif cardImage then
                -- Original image: draw with normal scaling
                love.graphics.draw(cardImage, 0, 0, 0,
                    config.CARD.width / cardImage:getWidth(),
                    config.CARD.height / cardImage:getHeight())
            end
        else
            local bodyColor = card.faceDown and {0.15, 0.15, 0.2} or card.color or {0.12, 0.12, 0.16}
            applyColor(bodyColor[1], bodyColor[2], bodyColor[3], bodyColor[4])
            love.graphics.rectangle("fill", 0, 0, config.CARD.width, config.CARD.height, cornerRadius, cornerRadius)
            
            -- Only draw inner lines when there is no image; when an image exists we skip them
            -- applyColor(0, 0, 0, 0.35)
            -- love.graphics.rectangle("line", 0, 0, config.CARD.width, config.CARD.height, cornerRadius, cornerRadius)

            local previousFont = love.graphics.getFont()
            love.graphics.setFont(game.fonts.card or previousFont)
            if not card.faceDown then
                applyColor((card.textColor and card.textColor[1]) or 0.08, (card.textColor and card.textColor[2]) or 0.08, (card.textColor and card.textColor[3]) or 0.08)
                love.graphics.printf(card.label, 8, 8, config.CARD.width - 16, "left")
            else
                applyColor(0.8, 0.8, 0.9)
                love.graphics.printf("?", 0, config.CARD.height / 2 - 12, config.CARD.width, "center")
            end
            love.graphics.setFont(previousFont)
        end
        
        -- Disable stencil so we can draw the border on top (or outside the clipped area)
        love.graphics.setStencilTest()

        -- Draw sharpened outline to enhance card edges
        local outlineConfig = config.CARD_OUTLINE or {}
        if outlineConfig.enabled and not card.disableOutline then
            local previousLineWidth = love.graphics.getLineWidth()
            local outlineWidth = outlineConfig.width or 2
            local outlineColor = outlineConfig.color or {0, 0, 0, 0.6}
            -- Use a unified corner radius
            
            applyColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.6)
            love.graphics.setLineWidth(outlineWidth)
            love.graphics.rectangle("line", 0, 0, config.CARD.width, config.CARD.height, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(previousLineWidth)
        end
    end

    -- Draw card shadow
    if shadowConfig.enabled and not card.disableShadow then
        local shadowColor = shadowConfig.color or {0, 0, 0, 0.4}
        local shadowScale = (shadowConfig.scale or 1) * scale
        local shadowScaleX = shadowScale
        local shadowScaleY = shadowScale
        if card.isFlipping then
            local duration = card.flipDuration or 0.45
            local progress = math.min(1, (card.flipElapsed or 0) / duration)
            shadowScaleX = shadowScale * math.max(0.15, math.abs(math.cos(progress * math.pi)))
            shadowScaleY = shadowScale
        end
        local cornerRadius = config.CARD_CORNER_RADIUS or 12
        love.graphics.push()
        love.graphics.translate(drawX + (shadowConfig.offsetX or 8) + config.CARD.width / 2,
            drawY + (shadowConfig.offsetY or 10) + config.CARD.height / 2)
        love.graphics.scale(shadowScaleX, shadowScaleY)
        love.graphics.translate(-config.CARD.width / 2, -config.CARD.height / 2)
        applyColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 0.4)
        love.graphics.rectangle("fill", 0, 0, config.CARD.width, config.CARD.height, cornerRadius, cornerRadius)
        love.graphics.pop()
    end

    -- Draw hover outline
    if applyHoverEffect then
        local padding = hoverEffect.outlinePadding or 4
        local outlineColor = hoverEffect.outlineColor or {1, 1, 1, 0.35}
        local previousLineWidth = love.graphics.getLineWidth()
        applyColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 1)
        love.graphics.setLineWidth(hoverEffect.outlineWidth or 2)
        love.graphics.rectangle("line",
            drawX - padding,
            drawY - padding,
            config.CARD.width + padding * 2,
            config.CARD.height + padding * 2,
            10, 10)
        love.graphics.setLineWidth(previousLineWidth)
    end

    -- Draw the card (with scale/offset)
    love.graphics.push()
    love.graphics.translate(drawX + config.CARD.width / 2, drawY + config.CARD.height / 2)
    local flipScaleX = 1
    if card.isFlipping then
        local duration = card.flipDuration or 0.45
        local progress = math.min(1, (card.flipElapsed or 0) / duration)
        flipScaleX = math.max(0.12, math.abs(math.cos(progress * math.pi)))
    end
    love.graphics.scale(scale * flipScaleX, scale)
    love.graphics.translate(-config.CARD.width / 2, -config.CARD.height / 2)
    drawCardContents()
    love.graphics.pop()
    
    -- Reset shader if it was applied
    if shaderApplied then
        shaders.resetShader()
    end
end

function ui.drawZone(zone)
    if not zone then
        return
    end

    layout_debugger.registerRect(
        "zone:" .. tostring(zone.id),
        zone,
        {
            category = "zone",
            color = {0.2, 0.7, 1.0, 0.2},
        }
    )

    -- Special handling for the deck zone: always draw the back image or a test color
    if zone.id == "drawPile" then
        local cornerRadius = config.CARD_CORNER_RADIUS or 12
        local assets_manager = require("assets_manager")
        local cardBack = assets_manager.images.cardBack
        
        -- Always draw the deck area (regardless of whether an image exists)
        local function stencilFunc()
            love.graphics.rectangle("fill", zone.x, zone.y, zone.width, zone.height, cornerRadius, cornerRadius)
        end
        love.graphics.stencil(stencilFunc, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        
        if cardBack then
            -- Image exists: draw it
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cardBack, zone.x, zone.y, 0, zone.width / cardBack:getWidth(), zone.height / cardBack:getHeight())
        else
            -- No image: draw a bright red rectangle
            love.graphics.setColor(1, 0, 0, 1)  -- pure red
            love.graphics.rectangle("fill", zone.x, zone.y, zone.width, zone.height, cornerRadius, cornerRadius)
        end
        
        love.graphics.setStencilTest()
        
        -- Draw border
        local outlineConfig = config.CARD_OUTLINE or {}
        if outlineConfig.enabled then
            local previousLineWidth = love.graphics.getLineWidth()
            local outlineWidth = outlineConfig.width or 2
            local outlineColor = outlineConfig.color or {0, 0, 0, 0.6}
            love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.6)
            love.graphics.setLineWidth(outlineWidth)
            love.graphics.rectangle("line", zone.x, zone.y, zone.width, zone.height, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(previousLineWidth)
        end
        
        -- Draw label (above the deck zone)
        if zone.label then
            love.graphics.setColor(0.85, 0.9, 1, 0.8)
            love.graphics.printf(zone.label, zone.x, zone.y - 26, zone.width, "center")
        end
        
        return
    end

    local zoneStyle = config.ZONE_STYLE or {}
    local hideHandZone = not zoneStyle.showHandZones and (zone.id == "playerHand" or zone.id == "opponentHand")
    if not hideHandZone then
        love.graphics.setColor(zone.color)
        love.graphics.rectangle("fill", zone.x, zone.y, zone.width, zone.height, 12, 12)
        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.rectangle("line", zone.x, zone.y, zone.width, zone.height, 12, 12)
    elseif zoneStyle.showHandZoneOutline then
        love.graphics.setColor(1, 1, 1, 0.05)
        love.graphics.rectangle("line", zone.x, zone.y, zone.width, zone.height, 12, 12)
    end
    local showLabel = zone.label and zone.id ~= "playerHand" and zone.id ~= "opponentHand"
    if showLabel then
        love.graphics.setColor(0.85, 0.9, 1, 0.8)
        local labelY = zone.y + 10
        love.graphics.print(zone.label, zone.x + 12, labelY)
    end
end

function ui.updateCardPosition(card, dt)
    if card.isDragging then
        return
    end
    if card.moveDelay and card.moveDelay > 0 then
        card.moveDelay = math.max(0, card.moveDelay - dt)
        return
    end
    local utils = require("utils")
    card.x = utils.lerp(card.x, card.targetX, math.min(1, dt * 10))
    card.y = utils.lerp(card.y, card.targetY, math.min(1, dt * 10))
    updateCardFlipState(card, dt)
end

function ui.buildButtons(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local buttonWidth, buttonHeight = 160, 48
    local spacing = 24
    local centerX = w / 2
    local baseY = h - 90
    for _, btn in ipairs(game.buttons) do
        btn.width = buttonWidth
        btn.height = buttonHeight
        btn.x = centerX - (buttonWidth / 2) + (btn.offset * (buttonWidth + spacing))
        btn.y = baseY
    end
end

function ui.buildMenuButtons(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local buttonWidth, buttonHeight = 220, 56
    local spacing = 20
    local startY = h / 2
    for i, btn in ipairs(game.menuButtons) do
        btn.width = buttonWidth
        btn.height = buttonHeight
        btn.x = (w - buttonWidth) / 2
        btn.y = startY + (i - 1) * (buttonHeight + spacing)
    end
end

function ui.buildResultButtons(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local buttonWidth, buttonHeight = 220, 56
    local spacing = 20
    local startY = h * 0.55
    for i, btn in ipairs(game.resultButtons) do
        btn.width = buttonWidth
        btn.height = buttonHeight
        btn.x = (w - buttonWidth) / 2
        btn.y = startY + (i - 1) * (buttonHeight + spacing)
    end
end

return ui


