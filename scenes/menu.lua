local menu = {}
local config = require("config")
local utils = require("utils")
local lan_mode = require("modes.lan_mode")
local mode_select = require("scenes.mode_select")
local utf8 = require("utf8")
local menuBg = require("menu_background")
local layout_debugger = require("tools.layout_debugger")

-- Split a UTF-8 string into a table of characters
local function utf8Chars(text)
    local chars = {}
    local len = utf8.len(text)
    if not len then return chars end
    local byteIndex = 1
    for i = 1, len do
        local nextIndex = utf8.offset(text, i + 1)
        local ch = text:sub(byteIndex, (nextIndex and nextIndex - 1) or -1)
        table.insert(chars, ch)
        byteIndex = nextIndex or (#text + 1)
    end
    return chars
end

local function ensureProfileEditor(game)
    game.profileEditor = game.profileEditor or {
        active = false,
        name = "",
        avatar = "",
        focused = nil,
        message = "",
        boxes = {},
        buttons = {},
    }
end

local function openProfileEditor(game)
    ensureProfileEditor(game)
    local editor = game.profileEditor
    local profile = game.profile
    editor.active = true
    editor.name = profile and profile.getName() or "Player"
    editor.avatar = profile and profile.getAvatarPath() or ""
    editor.focused = "name"
    editor.message = ""
end

local function closeProfileEditor(game)
    ensureProfileEditor(game)
    game.profileEditor.active = false
    game.profileEditor.message = ""
end

function menu.initialize(game)
    ensureProfileEditor(game)
    menuBg.init()  -- Initialize background animation
    
    game.menuButtons = {
        {
            id = "menu_local",
            label = "Local Mode (Player vs AI)",
            action = function()
                mode_select.enter(game)
            end,
        },
        {
            id = "menu_lan",
            label = "LAN Mode (In Development)",
            action = function()
                lan_mode.enter(game)
            end,
        },
        {
            id = "menu_profile",
            label = "Edit Profile",
            action = function()
                openProfileEditor(game)
            end,
        },
        {
            id = "menu_tutorial",
            label = "View Tutorial",
            action = function()
                game.showTutorial = not game.showTutorial
                game.tutorialState = 1
                game.tutorialLastAdvance = love.timer.getTime()
            end,
        },
        {
            id = "menu_quit",
            label = "Quit Game",
            action = function()
                love.event.quit()
            end,
        },
    }
end

local function drawProfileCard(game)
    local profile = game.profile
    if not profile then
        return
    end
    local w = love.graphics.getWidth()
    local cardWidth = 240
    local cardHeight = 120
    local x = w - cardWidth - 40
    local y = 60
    love.graphics.setColor(0.16, 0.2, 0.28, 0.9)
    love.graphics.rectangle("fill", x, y, cardWidth, cardHeight, 12, 12)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 12, 12)
    love.graphics.setColor(0.95, 0.97, 1, 0.95)
    local avatar = profile.getAvatarImage and profile.getAvatarImage()
    if avatar then
        local size = 72
        love.graphics.draw(avatar, x + 20, y + 16, 0, size / avatar:getWidth(), size / avatar:getHeight())
    else
        love.graphics.setColor(0.3, 0.34, 0.42, 0.8)
        love.graphics.rectangle("fill", x + 20, y + 16, 72, 72, 8, 8)
        love.graphics.setColor(0.95, 0.97, 1, 0.6)
        love.graphics.printf("No Avatar", x + 20, y + 46, 72, "center")
        love.graphics.setColor(0.95, 0.97, 1, 0.95)
    end
    love.graphics.printf("Player Name", x + 110, y + 20, cardWidth - 140, "left")
    love.graphics.printf(profile.getName and profile.getName() or "Player", x + 110, y + 48, cardWidth - 140, "left")
end

local function drawEditorButton(editor, label, x, y, width, height, enabled, action)
    love.graphics.setColor(0.2, 0.32, 0.5, enabled ~= false and 0.95 or 0.4)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)
    love.graphics.setColor(0.95, 0.97, 1, enabled ~= false and 0.95 or 0.6)
    -- Use slightly smaller font for editor buttons if available
    if _G.game and _G.game.fonts and _G.game.fonts.button then
        love.graphics.setFont(_G.game.fonts.button)
    end
    love.graphics.printf(label, x, y + 12, width, "center")
    editor.buttonZones = editor.buttonZones or {}
    table.insert(editor.buttonZones, {x = x, y = y, width = width, height = height, enabled = enabled ~= false, action = action})
end

local function drawButtons(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local buttonWidth, buttonHeight = 260, 60
    local spacing = 18
    local startY = h * 0.38
    local mx, my = love.mouse.getPosition()

    for index, btn in ipairs(game.menuButtons) do
        btn.x = (w - buttonWidth) / 2
        btn.y = startY + (index - 1) * (buttonHeight + spacing)
        btn.width = buttonWidth
        btn.height = buttonHeight

        local x, y = btn.x, btn.y
        local hovered = mx >= x and mx <= x + buttonWidth and my >= y and my <= y + buttonHeight
 
        -- Slight scale and lift when hovered
        local scale = hovered and 1.04 or 1.0
        local lift = hovered and 3 or 0

        love.graphics.push()
        love.graphics.translate(x + buttonWidth / 2, y + buttonHeight / 2 - lift)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-buttonWidth / 2, -buttonHeight / 2)

        local cornerRadius = 14
 
        -- Button shadow
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", 4, 6, buttonWidth, buttonHeight, cornerRadius + 2, cornerRadius + 2)
 
        -- Gradient body (lighter at the top, darker at the bottom)
        local topColor  = hovered and {0.28, 0.46, 0.80} or {0.20, 0.34, 0.60}
        local midColor  = hovered and {0.16, 0.28, 0.55} or {0.12, 0.22, 0.45}
        local bottomColor = hovered and {0.10, 0.18, 0.38} or {0.08, 0.14, 0.30}
 
        -- Base rounded rectangle shape
        love.graphics.setColor(midColor[1], midColor[2], midColor[3], 0.98)
        love.graphics.rectangle("fill", 0, 0, buttonWidth, buttonHeight, cornerRadius, cornerRadius)
 
        -- Top gradient layer (slightly inset, smaller radius, keeps corners smooth)
        local inset = 1.0
        local innerRadius = cornerRadius - 2
        love.graphics.setColor(topColor[1], topColor[2], topColor[3], 0.98)
        love.graphics.rectangle("fill", inset, inset, buttonWidth - inset * 2, buttonHeight * 0.45,
            innerRadius, innerRadius)
 
        -- Bottom gradient layer
        love.graphics.setColor(bottomColor[1], bottomColor[2], bottomColor[3], 0.98)
        love.graphics.rectangle("fill", inset, buttonHeight * 0.55, buttonWidth - inset * 2,
            buttonHeight * 0.45, innerRadius, innerRadius)
 
        -- Middle transition band
        love.graphics.setColor(midColor[1], midColor[2], midColor[3], 0.98)
        love.graphics.rectangle("fill", inset, buttonHeight * 0.28, buttonWidth - inset * 2, buttonHeight * 0.44)
 
        -- Inner glow stroke
        love.graphics.setColor(1, 1, 1, hovered and 0.40 or 0.28)
        love.graphics.rectangle("line", 1.5, 1.5, buttonWidth - 3, buttonHeight - 3, cornerRadius - 2, cornerRadius - 2)
 
        -- Outer dark stroke
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 0, 0, buttonWidth, buttonHeight, cornerRadius, cornerRadius)
        love.graphics.setLineWidth(1)
 
        -- Button text
        love.graphics.setColor(0.96, 0.98, 1.0, 1.0)
        love.graphics.setFont(game.fonts.button or game.fonts.primary)
        love.graphics.printf(btn.label, 0, buttonHeight / 2 - 12, buttonWidth, "center")

        love.graphics.pop()

        layout_debugger.registerRect(
            "menu_button:" .. tostring(btn.id),
            btn,
            {
                category = "menu_button",
                color = {0.85, 0.55, 1.0, 0.35},
            }
        )
    end
end

local function drawTutorialOverlay(game)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(0.95, 0.95, 0.98)
    love.graphics.setFont(game.fonts.card or game.fonts.primary)
    love.graphics.printf("Game Tutorial", 0, love.graphics.getHeight() * 0.18, love.graphics.getWidth(), "center")
    love.graphics.setFont(game.fonts.primary)
    love.graphics.printf(config.TUTORIAL_MESSAGES[game.tutorialState],
        love.graphics.getWidth() * 0.1,
        love.graphics.getHeight() * 0.3,
        love.graphics.getWidth() * 0.8,
        "center")
    love.graphics.printf("← / → Switch pages, Esc to close", 0, love.graphics.getHeight() * 0.75, love.graphics.getWidth(), "center")
end

local function drawInputField(label, value, isFocused, x, y, width, height)
    love.graphics.setColor(0.9, 0.92, 0.98, 0.9)
    love.graphics.printf(label, x, y - 28, width, "left")
    love.graphics.setColor(isFocused and 0.25 or 0.16, isFocused and 0.38 or 0.22, 0.55, 0.95)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", x, y, width, height, 8, 8)
    love.graphics.setColor(0.95, 0.97, 1, 0.95)
    love.graphics.printf(value, x + 12, y + height / 2 - 10, width - 24, "left")
end

local function drawAvatarPicker(game, panelX, panelY, panelWidth)
    local editor = game.profileEditor
    if not editor.pickerActive then
        return
    end
    editor.avatarEntries = editor.avatarEntries or (game.profile and game.profile.listAvatars and game.profile.listAvatars() or {})
    local entries = editor.avatarEntries
    local pickerWidth = panelWidth - 60
    local pickerHeight = 140
    local pickerX = panelX + 30
    local pickerY = panelY + 230
    love.graphics.setColor(0.1, 0.14, 0.2, 0.95)
    love.graphics.rectangle("fill", pickerX, pickerY, pickerWidth, pickerHeight, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("line", pickerX, pickerY, pickerWidth, pickerHeight, 10, 10)
    editor.pickerZones = {}
    if #entries == 0 then
        love.graphics.setColor(0.9, 0.85, 0.5, 0.95)
        love.graphics.printf("No images found. Put images into the assets/avatars/ folder and click refresh.", pickerX + 12, pickerY + 20, pickerWidth - 24, "left")
        return
    end
    local entryHeight = 36
    for i, entry in ipairs(entries) do
        if i > math.floor(pickerHeight / entryHeight) then
            break
        end
        local y = pickerY + 8 + (i - 1) * entryHeight
        love.graphics.setColor(0.2, 0.28, 0.42, 0.9)
        love.graphics.rectangle("fill", pickerX + 8, y, pickerWidth - 16, entryHeight - 6, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("line", pickerX + 8, y, pickerWidth - 16, entryHeight - 6, 6, 6)
        love.graphics.setColor(0.95, 0.97, 1, 0.95)
        love.graphics.printf(entry.name, pickerX + 20, y + 6, pickerWidth - 40, "left")
        table.insert(editor.pickerZones, {x = pickerX + 8, y = y, width = pickerWidth - 16, height = entryHeight - 6, action = "selectAvatar", path = entry.path})
    end
end

local function drawProfileEditor(game)
    local editor = game.profileEditor
    if not editor or not editor.active then
        editor.buttonZones = {}
        return
    end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local panelWidth, panelHeight = 460, 360
    local panelX = (w - panelWidth) / 2
    local panelY = (h - panelHeight) / 2
    love.graphics.setColor(0.12, 0.16, 0.22, 0.98)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 12, 12)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 12, 12)
    love.graphics.setColor(0.95, 0.97, 1, 0.95)
    love.graphics.setFont(game.fonts.primary)
    love.graphics.printf("Edit Profile", panelX, panelY + 20, panelWidth, "center")
    local inputWidth = panelWidth - 60
    local inputHeight = 48
    editor.boxes = editor.boxes or {}
    editor.buttonZones = {}
    drawInputField("Nickname", editor.name, editor.focused == "name", panelX + 30, panelY + 70, inputWidth, inputHeight)
    editor.boxes.name = {x = panelX + 30, y = panelY + 70, width = inputWidth, height = inputHeight}
    drawInputField("Avatar path (relative, can be empty)", editor.avatar, editor.focused == "avatar", panelX + 30, panelY + 140, inputWidth, inputHeight)
    editor.boxes.avatar = {x = panelX + 30, y = panelY + 140, width = inputWidth, height = inputHeight}
        love.graphics.setColor(0.85, 0.88, 0.96, 0.9)
        love.graphics.printf("Hint: avatar feature is temporarily disabled.", panelX + 30, panelY + 200, inputWidth, "left")
    if editor.message and editor.message ~= "" then
        love.graphics.setColor(0.9, 0.6, 0.4, 0.95)
        love.graphics.printf(editor.message, panelX + 30, panelY + 280, inputWidth, "left")
    end
    -- Use slightly smaller font for the Save/Cancel buttons
    love.graphics.setFont(game.fonts.button or game.fonts.primary)
    drawEditorButton(editor, "Save", panelX + 30, panelY + panelHeight - 70, 160, 48, true, "save")
    drawEditorButton(editor, "Cancel", panelX + panelWidth - 190, panelY + panelHeight - 70, 160, 48, true, "cancel")
    editor.pickerActive = false
end

function menu.handleClick(game, x, y)
    ensureProfileEditor(game)
    if game.profileEditor.active then
        local boxes = game.profileEditor.boxes or {}
        for field, rect in pairs(boxes) do
            if utils.pointInRect(rect, x, y) then
                game.profileEditor.focused = field
                return true
            end
        end
        local profile = game.profile
        for _, zone in ipairs(game.profileEditor.buttonZones or {}) do
            if zone.enabled and utils.pointInRect(zone, x, y) then
                if zone.action == "save" then
                    profile.setName(game.profileEditor.name)
                    local ok, err = profile.setAvatar(game.profileEditor.avatar)
                    if not ok and err then
                        game.profileEditor.message = err
                        return true
                    end
                    closeProfileEditor(game)
                elseif zone.action == "cancel" then
                    closeProfileEditor(game)
                end
                return true
            end
        end
        return true
    end
    for _, btn in ipairs(game.menuButtons) do
        if utils.pointInRect(btn, x, y) then
            if btn.action then
                btn.action()
            end
            return true
        end
    end
    return false
end

local function appendChar(editor, text)
    if not editor.focused or text == "" then
        return
    end
    editor[editor.focused] = (editor[editor.focused] or "") .. text
end

local function removeLastChar(str)
    if not str or str == "" then
        return ""
    end
    local byteoffset = utf8.offset(str, -1)
    if byteoffset then
        return str:sub(1, byteoffset - 1)
    end
    return ""
end

function menu.handleTextInput(game, text)
    ensureProfileEditor(game)
    if game.profileEditor.active then
        appendChar(game.profileEditor, text)
        return true
    end
    return false
end

local function cycleFocus(editor)
    if editor.focused == "name" then
        editor.focused = "avatar"
    else
        editor.focused = "name"
    end
end

function menu.handleKey(game, key)
    ensureProfileEditor(game)
    if game.profileEditor.active then
        if key == "escape" then
            closeProfileEditor(game)
            return true
        elseif key == "tab" then
            cycleFocus(game.profileEditor)
            return true
        elseif key == "backspace" then
            local field = game.profileEditor.focused
            if field and #game.profileEditor[field] > 0 then
                game.profileEditor[field] = removeLastChar(game.profileEditor[field])
            end
            return true
        elseif key == "return" or key == "kpenter" then
            local profile = game.profile
            profile.setName(game.profileEditor.name)
            local ok, err = profile.setAvatar(game.profileEditor.avatar)
            if not ok and err then
                game.profileEditor.message = err
                return true
            end
            closeProfileEditor(game)
            return true
        end
        return false
    end
    if game.showTutorial then
        if key == "escape" then
            game.showTutorial = not game.showTutorial
            game.tutorialState = 1
            game.tutorialLastAdvance = love.timer.getTime()
            return true
        elseif key == "left" then
            local now = love.timer.getTime()
            if now - game.tutorialLastAdvance >= 0.2 then
                game.tutorialState = game.tutorialState - 1
                if game.tutorialState < 1 then
                    game.tutorialState = #config.TUTORIAL_MESSAGES
                end
                game.tutorialLastAdvance = now
            end
            return true
        elseif key == "right" then
            local now = love.timer.getTime()
            if now - game.tutorialLastAdvance >= 0.2 then
                game.tutorialState = game.tutorialState + 1
                if game.tutorialState > #config.TUTORIAL_MESSAGES then
                    game.tutorialState = 1
                end
                game.tutorialLastAdvance = now
            end
            return true
        end
    end
    return false
end

function menu.draw(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- Clear background to a dark color first
    love.graphics.clear(0.08, 0.09, 0.12)
    
    -- Draw semi-transparent background image
    if game.menuBackgroundImage then
        love.graphics.setColor(1, 1, 1, 0.6)  -- 60% opacity
        local imgW, imgH = game.menuBackgroundImage:getDimensions()
        local scaleX = w / imgW
        local scaleY = h / imgH
        local scale = math.max(scaleX, scaleY)  -- fill the screen
        local drawX = (w - imgW * scale) / 2
        local drawY = (h - imgH * scale) / 2
        love.graphics.draw(game.menuBackgroundImage, drawX, drawY, 0, scale, scale)
    end
    
    -- Draw falling-card background animation on top of the image
    love.graphics.setColor(1, 1, 1, 1)  -- reset color
    menuBg.draw()
 
    -- Glowing title text (casino style)
    local now = love.timer.getTime()
    local title = "Ten and a Half Cards"
    local subTitle = "Shuffle, hit, and try to get close to 10.5 points"

    local titleX = 40
    local titleY = h * 0.18
    local titleWidth = w - 80
 
    -- Base title brightness (subtle breathing effect)
    local basePulse = (math.sin(now * 1.2) + 1) * 0.5
    local baseGlow  = 0.18 + basePulse * 0.2
 
    -- Neon gradient color (red → yellow → purple loop)
    local huePhase = (now * 0.25) % 3.0
    local r, g, b
    if huePhase < 1.0 then
        -- Red → Yellow
        local t = huePhase
        r = 1.0
        g = 0.2 + 0.6 * t   -- 0.2 -> 0.8
        b = 0.2 * (1.0 - t) -- 0.2 -> 0.0
    elseif huePhase < 2.0 then
        -- Yellow → Purple
        local t = huePhase - 1.0
        r = 1.0 - 0.3 * t   -- 1.0 -> 0.7
        g = 0.8 - 0.8 * t   -- 0.8 -> 0.0
        b = 0.0 + 0.8 * t   -- 0.0 -> 0.8
    else
        -- Purple → Red
        local t = huePhase - 2.0
        r = 0.7 + 0.3 * t   -- 0.7 -> 1.0
        g = 0.0 + 0.2 * t   -- 0.0 -> 0.2
        b = 0.8 - 0.6 * t   -- 0.8 -> 0.2
    end
 
    love.graphics.setFont(game.fonts.title or game.fonts.primary)
 
    -- Draw neon effect character by character
    local titleChars = utf8Chars(title)
    local charCount = #titleChars
    local font = love.graphics.getFont()
    local cursorX = titleX
 
    for i, ch in ipairs(titleChars) do
        local chWidth = font:getWidth(ch)
        local centerX = cursorX + chWidth / 2
 
        -- LED marquee: highlight characters one by one
        local speed = 12.0                          -- marquee speed
        local pos = (now * speed + i) % charCount   -- current LED position
        local dist = math.min(math.abs(pos - i), charCount - math.abs(pos - i))
        local highlight = math.max(0, 1.0 - dist * 1.8)  -- closer to the lit position → brighter
 
        -- Final glow strength per character
        local charGlowAlpha = baseGlow + highlight * 0.55
 
        -- Outer colorful neon glow (global r,g,b, per-character alpha)
        love.graphics.setColor(r, g, b, charGlowAlpha)
        local offsets = {
            {-2,  0}, {2,  0},
            { 0, -2}, {0,  2},
            {-2, -2}, {2, -2},
            {-2,  2}, {2,  2},
        }
        for _, o in ipairs(offsets) do
            love.graphics.print(ch, centerX + o[1] - chWidth / 2, titleY + o[2])
        end
 
        -- Inner brighter stroke in the same color
        local innerR = math.min(1.0, r + 0.15)
        local innerG = math.min(1.0, g + 0.15)
        local innerB = math.min(1.0, b + 0.15)
        love.graphics.setColor(innerR, innerG, innerB, charGlowAlpha * 0.7)
        love.graphics.print(ch, centerX - chWidth / 2, titleY + 1)
 
        -- Main pure white text
        love.graphics.setColor(0.98, 0.98, 1.0, 1.0)
        love.graphics.print(ch, centerX - chWidth / 2, titleY)
 
        cursorX = cursorX + chWidth
    end
 
    -- Subtitle with subtle glow
    local subY = h * 0.28
    local subWidth = w - 80
    local subPulse = (math.sin(now * 1.4 + 1.0) + 1) * 0.5
    local subFlicker = (math.sin(now * 12.0 + 0.7) + 1) * 0.5
    local subGlowAlpha = 0.16 + subPulse * 0.18 + subFlicker * 0.08

    love.graphics.setFont(game.fonts.primary)
    love.graphics.setColor(1.0, 0.92, 0.7, subGlowAlpha)
    for _, o in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
        love.graphics.printf(subTitle, titleX + o[1], subY + o[2], subWidth, "left")
    end

    love.graphics.setColor(0.95, 0.95, 0.98, 1.0)
    love.graphics.printf(subTitle, titleX, subY, subWidth, "left")
    drawProfileCard(game)
    drawButtons(game)
    if game.showTutorial then
        drawTutorialOverlay(game)
    end
    drawProfileEditor(game)
end

-- Update menu animation
function menu.update(dt)
    menuBg.update(dt)
end

return menu




