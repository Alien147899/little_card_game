-- Game table scene
local table_scene = {}
local card = require("card")
local game_logic = require("game_logic")
local ui = require("ui")
local config = require("config")
local utils = require("utils")
local local_mode = require("modes.local_mode")
local lan_mode = require("modes.lan_mode")
local layout_debugger = require("tools.layout_debugger")

local function drawBackground(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if game.backgroundImage then
        love.graphics.setColor(1, 1, 1)
        local img = game.backgroundImage
        local scaleX = w / img:getWidth()
        local scaleY = h / img:getHeight()
        love.graphics.draw(img, 0, 0, 0, scaleX, scaleY)

        -- Overlay a semi-transparent color to reduce background brightness
        local overlay = (config.BACKGROUND and config.BACKGROUND.overlay)
        if overlay then
            love.graphics.setColor(overlay[1], overlay[2], overlay[3], overlay[4] or 0.4)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    else
        local bgColor = (config.BACKGROUND and config.BACKGROUND.color) or {0.08, 0.09, 0.12}
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3])
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

function table_scene.initializeButtons(game)
    game.buttons = {
        {
            id = "start",
            label = "Start New Round",
            offset = 0,
            visibleStates = {await_start = true, round_over = true, match_over = true},
            action = function()
                lan_mode.handleGameplayAction(game, "start_round", ui)
            end,
        },
        {
            id = "hit",
            label = "Hit",
            offset = -1,
            visibleStates = {player_turn = true},
            action = function()
                lan_mode.handleGameplayAction(game, "hit", ui)
            end,
        },
        {
            id = "stand",
            label = "Stand",
            offset = 1,
            visibleStates = {player_turn = true},
            action = function()
                lan_mode.handleGameplayAction(game, "stand", ui)
            end,
        },
    }
end

local function ensurePauseOverlay(game)
    game.pauseOverlay = game.pauseOverlay or {active = false, buttons = {}}
    game.pauseOverlay.buttons = game.pauseOverlay.buttons or {}
end

function table_scene.buildPauseButtons(game)
    ensurePauseOverlay(game)
    local overlay = game.pauseOverlay
    overlay.buttons = {}
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local panelWidth, panelHeight = 380, 230
    local panelX = (w - panelWidth) / 2
    local panelY = (h - panelHeight) / 2
    overlay.panel = {x = panelX, y = panelY, width = panelWidth, height = panelHeight}
    local buttonWidth = panelWidth - 80
    local buttonHeight = 50
    local startY = panelY + 80
    local entries = {
        {
            id = "pause_menu",
            label = "Back to Main Menu",
            action = function()
                table_scene.hidePauseOverlay(game)
                local_mode.returnToMenu(game)
            end,
        },
        {
            id = "pause_resume",
            label = "Return to Game",
            action = function()
                table_scene.hidePauseOverlay(game)
            end,
        },
    }
    for index, btn in ipairs(entries) do
        local btnY = startY + (index - 1) * (buttonHeight + 20)
        overlay.buttons[index] = {
            id = btn.id,
            label = btn.label,
            x = panelX + (panelWidth - buttonWidth) / 2,
            y = btnY,
            width = buttonWidth,
            height = buttonHeight,
            action = btn.action,
        }
    end
end

function table_scene.showPauseOverlay(game)
    ensurePauseOverlay(game)
    table_scene.buildPauseButtons(game)
    game.pauseOverlay.active = true
end

function table_scene.hidePauseOverlay(game)
    if game.pauseOverlay then
        game.pauseOverlay.active = false
    end
end

function table_scene.handlePauseClick(game, x, y)
    if not (game.pauseOverlay and game.pauseOverlay.active) then
        return false
    end
    for _, btn in ipairs(game.pauseOverlay.buttons or {}) do
        if utils.pointInRect(btn, x, y) then
            if btn.action then
                btn.action()
            end
            return true
        end
    end
    return true
end

function table_scene.draw(game)
    drawBackground(game)
    love.graphics.setFont(game.fonts.primary)
    ui.drawZone(game.zones.opponentHand)
    if game.zones.playArea then
        ui.drawZone(game.zones.playArea)
    end
    ui.drawZone(game.zones.playerHand)

    -- draw pile
    local deckZone = game.zones.drawPile
    
    -- Draw the deck back image (using a pre-rendered Canvas, white background + centered logo)
    local assets_manager = require("assets_manager")
    local cardBackCanvas = assets_manager.images.cardBackCanvas
    local cornerRadius = config.CARD_CORNER_RADIUS or 12
    
    if cardBackCanvas then
        -- Use stencil to clip rounded corners
        local function stencilFunc()
            love.graphics.rectangle("fill", deckZone.x, deckZone.y, deckZone.width, deckZone.height, cornerRadius, cornerRadius)
        end
        love.graphics.stencil(stencilFunc, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        
        -- Apply reflection shader (deck itself does not float; use no tilt so the highlight stays static)
        local shaders = require("shaders")
        -- Deck keeps a static highlight: pass time = 0 and tilt = 0
        if config.SHADERS.ENABLED and shaders.applyCardBackStable(cardBackCanvas:getWidth(), cardBackCanvas:getHeight(), 0, 0, 0) then
            -- Draw with shader (static reflection effect)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cardBackCanvas, deckZone.x, deckZone.y, 0, 
                deckZone.width / cardBackCanvas:getWidth(), 
                deckZone.height / cardBackCanvas:getHeight())
            shaders.resetShader()
        else
            -- No shader available: draw normally
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cardBackCanvas, deckZone.x, deckZone.y, 0, 
                deckZone.width / cardBackCanvas:getWidth(), 
                deckZone.height / cardBackCanvas:getHeight())
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
            love.graphics.rectangle("line", deckZone.x, deckZone.y, deckZone.width, deckZone.height, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(previousLineWidth)
        end
    else
        -- No image: use the default deck style
        love.graphics.setColor(deckZone.color)
        love.graphics.rectangle("fill", deckZone.x, deckZone.y, deckZone.width, deckZone.height, 10, 10)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.rectangle("line", deckZone.x, deckZone.y, deckZone.width, deckZone.height, 10, 10)
    end
    
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf(deckZone.label, deckZone.x - 20, deckZone.y - 24, deckZone.width + 40, "center")
    love.graphics.printf("Cards left: " .. tostring(#game.deck), deckZone.x - 20, deckZone.y + config.CARD.height + 6, deckZone.width + 40, "center")

    local mouseX, mouseY = love.mouse.getPosition()
    local time = love.timer.getTime()

    if game.roleDraw and game.roleDraw.cards then
        for _, roleCard in ipairs(game.roleDraw.cards) do
            ui.drawCard(roleCard, game, mouseX, mouseY, time)
        end
    end
    
    -- LAN mode: use perspective to get hands and ensure opponent cards stay face down
    local isLanMode = (game.mode == "lan_game" and game.lan and game.lan.matchActive)
    local opponentHandToDraw = game.opponentHand
    local playerHandToDraw = game.playerHand
    
    if isLanMode then
        local perspective = require("lan.perspective")
        opponentHandToDraw = perspective.getOpponentHand(game)
        playerHandToDraw = perspective.getMyHand(game)
        
        -- Temporarily save opponent cards' faceDown state and force them to show back side
        local savedFaceDownStates = {}
        for i, card in ipairs(opponentHandToDraw) do
            savedFaceDownStates[i] = card.faceDown
            card.faceDown = true  -- force face-down rendering
        end
        
        -- Draw opponent hand (back side)
        for _, card in ipairs(opponentHandToDraw) do
            ui.drawCard(card, game, mouseX, mouseY, time)
        end
        
        -- Restore faceDown state
        for i, card in ipairs(opponentHandToDraw) do
            card.faceDown = savedFaceDownStates[i]
        end
    else
        -- Local mode: draw normally
        for _, card in ipairs(opponentHandToDraw) do
            ui.drawCard(card, game, mouseX, mouseY, time)
        end
    end

    for _, card in ipairs(game.boardCards) do
        if card ~= game.draggedCard then
            ui.drawCard(card, game, mouseX, mouseY, time)
        end
    end

    for _, card in ipairs(playerHandToDraw) do
        if card ~= game.draggedCard then
            ui.drawCard(card, game, mouseX, mouseY, time)
        end
    end

    if game.draggedCard then
        ui.drawCard(game.draggedCard, game, mouseX, mouseY, time)
    end

    if game.roleDraw and game.roleDraw.humanCard and game.roleDraw.aiCard then
        local labelFont = game.fonts.card or game.fonts.primary
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(labelFont)
        love.graphics.setColor(0.96, 0.97, 1, 0.9)
        local labelWidth = config.CARD.width + 80
        local playerCard = game.roleDraw.humanCard
        local aiCard = game.roleDraw.aiCard
        local playerLabelText = game.roleDraw.humanRevealed and playerCard.label or "??"
        local aiLabelText = game.roleDraw.aiRevealed and aiCard.label or "??"
        -- Move role labels slightly higher so they don't overlap the card graphics
        local labelOffsetY = 44
        love.graphics.printf("Your role card: " .. playerLabelText,
            playerCard.targetX - 40,
            playerCard.targetY - labelOffsetY,
            labelWidth,
            "center")
        love.graphics.printf("Opponent's role card: " .. aiLabelText,
            aiCard.targetX - 40,
            aiCard.targetY - labelOffsetY,
            labelWidth,
            "center")
        if game.roleDraw.stage == "resolved" then
            local humanRoleText = game.humanRole == "banker" and "Banker" or "Idle player"
            local aiRoleText = game.humanRole == "banker" and "Idle player" or "Banker"
            love.graphics.printf("You → " .. humanRoleText,
                playerCard.targetX - 40,
                playerCard.targetY + config.CARD.height + 6,
                labelWidth,
                "center")
            love.graphics.printf("Opponent → " .. aiRoleText,
                aiCard.targetX - 40,
                aiCard.targetY + config.CARD.height + 6,
                labelWidth,
                "center")
        else
            local playerHint = "Waiting for the deal..."
            if game.roleDraw.stage == "await_player" then
                playerHint = "Click to reveal your card"
            elseif game.roleDraw.stage == "player_flipping" then
                playerHint = "Revealing..."
            elseif game.roleDraw.stage == "ai_flipping" then
                playerHint = "Result will be revealed soon"
            end
            local aiHint = "Waiting for reveal"
            if game.roleDraw.stage == "ai_flipping" then
                aiHint = "Revealing..."
            end
            love.graphics.printf(playerHint,
                playerCard.targetX - 40,
                playerCard.targetY + config.CARD.height + 6,
                labelWidth,
                "center")
            love.graphics.printf(aiHint,
                aiCard.targetX - 40,
                aiCard.targetY + config.CARD.height + 6,
                labelWidth,
                "center")
        end
        love.graphics.setFont(prevFont)
    end

    if game.clearAnimation and game.clearAnimation.active then
        for _, animCard in ipairs(game.clearAnimation.cards) do
            animCard.disableHoverEffect = true
            animCard.disableIdleWobble = true
            ui.drawCard(animCard, game, mouseX, mouseY, time)
        end
    end

    -- LAN mode: use perspective to get values from the correct viewpoint
    local myHandToEval = playerHandToDraw
    local opponentHandToEval = opponentHandToDraw
    
    local humanValue = card.evaluateHand(myHandToEval)
    local aiValue = card.evaluateHand(opponentHandToEval)
    local aiValueText
    if game_logic.isHumanBanker(game) or game.revealDealer then
        aiValueText = card.formatValue(aiValue)
    else
        aiValueText = "?"
    end
    
    -- Simple status text
    local infoBaseY = love.graphics.getHeight() / 2 - 110
    local prevFont = love.graphics.getFont()
    if game.fonts.info then
        love.graphics.setFont(game.fonts.info)
    end
    love.graphics.setColor(0.92, 0.94, 0.98, 0.95)
    love.graphics.print("Status: " .. (game.message or ""), 40, infoBaseY)
    love.graphics.print(string.format("%s points %s / %d cards", game_logic.aiLabel(game), aiValueText, #opponentHandToEval), 40, infoBaseY + 26)
    love.graphics.print(string.format("%s points %s / %d cards", game_logic.humanLabel(game), card.formatValue(humanValue), #myHandToEval), 40, infoBaseY + 52)
    love.graphics.setFont(prevFont)

    local mx, my = love.mouse.getPosition()
    local buttonFont = game.fonts.button or game.fonts.primary
    for _, btn in ipairs(game.buttons) do
        if btn.visibleStates and btn.visibleStates[game.state] then
            -- Check whether the "Start New Round" button should be hidden
            local shouldHide = false
            if btn.id == "start" and (game.state == "round_over" or game.state == "await_start") then
                if game_logic.hasCardsMoving(game) or (game.clearAnimation and game.clearAnimation.active) then
                    shouldHide = true
                end
            end
            
            if not shouldHide then
                layout_debugger.registerRect(
                    "button:" .. tostring(btn.id),
                    btn,
                    {
                        category = "button",
                        color = {0.95, 0.75, 0.2, 0.4},
                    }
                )
                local x, y, bw, bh = btn.x, btn.y, btn.width, btn.height
                local hovered = mx >= x and mx <= x + bw and my >= y and my <= y + bh
                local scale = hovered and 1.04 or 1.0
                local lift = hovered and 2 or 0
                local cornerRadius = 12

                love.graphics.push()
                love.graphics.translate(x + bw / 2, y + bh / 2 - lift)
                love.graphics.scale(scale, scale)
                love.graphics.translate(-bw / 2, -bh / 2)

                -- Shadow
                love.graphics.setColor(0, 0, 0, 0.35)
                love.graphics.rectangle("fill", 3, 5, bw, bh, cornerRadius + 2, cornerRadius + 2)

                -- Gradient body
                local topColor  = hovered and {0.28, 0.46, 0.80} or {0.20, 0.34, 0.60}
                local midColor  = hovered and {0.16, 0.28, 0.55} or {0.12, 0.22, 0.45}
                local bottomColor = hovered and {0.10, 0.18, 0.38} or {0.08, 0.14, 0.30}

                love.graphics.setColor(midColor[1], midColor[2], midColor[3], 0.98)
                love.graphics.rectangle("fill", 0, 0, bw, bh, cornerRadius, cornerRadius)

                local inset = 1.0
                local innerRadius = cornerRadius - 2
                love.graphics.setColor(topColor[1], topColor[2], topColor[3], 0.98)
                love.graphics.rectangle("fill", inset, inset, bw - inset * 2, bh * 0.45,
                    innerRadius, innerRadius)

                love.graphics.setColor(bottomColor[1], bottomColor[2], bottomColor[3], 0.98)
                love.graphics.rectangle("fill", inset, bh * 0.55, bw - inset * 2,
                    bh * 0.45, innerRadius, innerRadius)

                love.graphics.setColor(midColor[1], midColor[2], midColor[3], 0.98)
                love.graphics.rectangle("fill", inset, bh * 0.28, bw - inset * 2, bh * 0.44)

                -- Inner stroke
                love.graphics.setColor(1, 1, 1, hovered and 0.40 or 0.28)
                love.graphics.rectangle("line", 1.5, 1.5, bw - 3, bh - 3, cornerRadius - 2, cornerRadius - 2)

                -- Outer stroke
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", 0, 0, bw, bh, cornerRadius, cornerRadius)
                love.graphics.setLineWidth(1)

                -- Button text
                love.graphics.setColor(0.96, 0.98, 1.0, 1.0)
                love.graphics.setFont(buttonFont)
                love.graphics.printf(btn.label, 0, bh / 2 - 10, bw, "center")

                love.graphics.pop()
            end
        end
    end

    love.graphics.setColor(0.8, 0.82, 0.9, 0.9)
    love.graphics.print("Drag your hand cards to reorder them; use the buttons below to Hit, Stand, or Start a New Round", 40, love.graphics.getHeight() - 36)

    if game.pauseOverlay and game.pauseOverlay.active then
        local overlay = game.pauseOverlay
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, w, h)
        local panel = overlay.panel or {x = w / 2 - 150, y = h / 2 - 120, width = 300, height = 220}
        love.graphics.setColor(0.13, 0.16, 0.22, 0.95)
        love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height, 14, 14)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height, 14, 14)
        love.graphics.setFont(game.fonts.card or game.fonts.primary)
        love.graphics.setColor(0.95, 0.96, 0.99)
        love.graphics.printf("Pause Menu", panel.x, panel.y + 20, panel.width, "center")
        love.graphics.setFont(game.fonts.primary)
        local mx2, my2 = love.mouse.getPosition()
        for _, btn in ipairs(overlay.buttons or {}) do
            local x, y, bw, bh = btn.x, btn.y, btn.width, btn.height
            local hovered = mx2 >= x and mx2 <= x + bw and my2 >= y and my2 <= y + bh
            local scale = hovered and 1.04 or 1.0
            local lift = hovered and 2 or 0
            local cornerRadius = 12

            love.graphics.push()
            love.graphics.translate(x + bw / 2, y + bh / 2 - lift)
            love.graphics.scale(scale, scale)
            love.graphics.translate(-bw / 2, -bh / 2)

            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle("fill", 3, 5, bw, bh, cornerRadius + 2, cornerRadius + 2)

            local topColor  = hovered and {0.28, 0.46, 0.80} or {0.20, 0.34, 0.60}
            local midColor  = hovered and {0.16, 0.28, 0.55} or {0.12, 0.22, 0.45}
            local bottomColor = hovered and {0.10, 0.18, 0.38} or {0.08, 0.14, 0.30}

            love.graphics.setColor(midColor[1], midColor[2], midColor[3], 0.98)
            love.graphics.rectangle("fill", 0, 0, bw, bh, cornerRadius, cornerRadius)

            local inset = 1.0
            local innerRadius = cornerRadius - 2
            love.graphics.setColor(topColor[1], topColor[2], topColor[3], 0.98)
            love.graphics.rectangle("fill", inset, inset, bw - inset * 2, bh * 0.45,
                innerRadius, innerRadius)

            love.graphics.setColor(bottomColor[1], bottomColor[2], bottomColor[3], 0.98)
            love.graphics.rectangle("fill", inset, bh * 0.55, bw - inset * 2,
                bh * 0.45, innerRadius, innerRadius)

            love.graphics.setColor(midColor[1], midColor[2], midColor[3], 0.98)
            love.graphics.rectangle("fill", inset, bh * 0.28, bw - inset * 2, bh * 0.44)

            love.graphics.setColor(1, 1, 1, hovered and 0.40 or 0.28)
            love.graphics.rectangle("line", 1.5, 1.5, bw - 3, bh - 3, cornerRadius - 2, cornerRadius - 2)

            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", 0, 0, bw, bh, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(0.96, 0.98, 1.0, 1.0)
            love.graphics.setFont(game.fonts.button or game.fonts.primary)
            love.graphics.printf(btn.label, 0, bh / 2 - 10, bw, "center")

            love.graphics.pop()
        end
    end
end

return table_scene







