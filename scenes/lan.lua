local lan_scene = {}
local utils = require("utils")
local lan_mode = require("modes.lan_mode")

local function clearZones(game)
    game.lanClickZones = {}
end

local function addZone(game, zone)
    table.insert(game.lanClickZones, zone)
end

local function drawButton(game, label, x, y, width, height, enabled, action)
    love.graphics.setColor(0.2, 0.32, 0.5, enabled and 0.95 or 0.4)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)
    love.graphics.setColor(0.95, 0.97, 1, enabled and 0.95 or 0.6)
    -- Slightly smaller font for LAN buttons
    if game and game.fonts and game.fonts.button then
        love.graphics.setFont(game.fonts.button)
    end
    love.graphics.printf(label, x, y + 15, width, "center")
    addZone(game, {x = x, y = y, width = width, height = height, enabled = enabled, action = action})
end

local function drawMenuView(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local buttonWidth, buttonHeight = 280, 58
    local startY = h * 0.35
    drawButton(game, "Create Room", (w - buttonWidth) / 2, startY, buttonWidth, buttonHeight, true, function()
        lan_mode.startHostLobby(game)
    end)
    drawButton(game, "Join Room", (w - buttonWidth) / 2, startY + buttonHeight + 24, buttonWidth, buttonHeight, true, function()
        lan_mode.openJoinList(game)
    end)
    -- Local test button (quickly connect to 127.0.0.1)
    drawButton(game, "Local Test (127.0.0.1)", (w - buttonWidth) / 2, startY + (buttonHeight + 24) * 2, buttonWidth, buttonHeight, true, function()
        lan_mode.connectByIP(game, "127.0.0.1")
    end)
    drawButton(game, "Back to Main Menu", (w - buttonWidth) / 2, startY + (buttonHeight + 24) * 3, buttonWidth, buttonHeight, true, function()
        lan_mode.backToMenu(game)
    end)
end

local function collectPlayers(game)
    local list = {}
    if game.lan.players then
        if game.lan.players.host then
            table.insert(list, game.lan.players.host)
        end
        if game.lan.players.guest then
            table.insert(list, game.lan.players.guest)
        end
    end
    return list
end

local function drawPlayers(game)
    local players = collectPlayers(game)
    local w = love.graphics.getWidth()
    local listWidth = math.min(480, w * 0.7)
    local listX = (w - listWidth) / 2
    local startY = love.graphics.getHeight() * 0.38
    for index, player in ipairs(players) do
        local y = startY + (index - 1) * 60
        love.graphics.setColor(0.18, 0.2, 0.32, 0.9)
        love.graphics.rectangle("fill", listX, y, listWidth, 50, 10, 10)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.rectangle("line", listX, y, listWidth, 50, 10, 10)
        love.graphics.setColor(0.95, 0.97, 1, 0.95)
        local name = player.name or "Player"
        if player.isHost then
            name = name .. " (Host)"
        end
        if player.isSelf then
            name = name .. " (You)"
        end
        love.graphics.printf(name, listX + 16, y + 12, listWidth * 0.6, "left")
        love.graphics.printf(player.ready and "Ready" or "Not Ready", listX, y + 12, listWidth - 20, "right")
    end
end

local function drawHostView(game)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    drawPlayers(game)
    local buttonWidth, buttonHeight = 220, 52
    local buttonsY = h * 0.7
    local localPlayer = nil
    if game.lan.role == "host" then
        localPlayer = game.lan.players.host
    elseif game.lan.role == "client" then
        localPlayer = game.lan.players.guest
    end
    local ready = localPlayer and localPlayer.ready or false
    
    -- Ready button: all players can click
    drawButton(game, ready and "Cancel Ready" or "Ready", w * 0.25 - buttonWidth / 2, buttonsY, buttonWidth, buttonHeight, true, function()
        lan_mode.toggleReady(game)
    end)
    
    -- Start match button: only visible to host
    if game.lan.role == "host" then
        local canStart = game.lan.allReady
        print(string.format("[LAN UI] Start match button: canStart=%s, allReady=%s, host.ready=%s, guest.ready=%s",
            tostring(canStart),
            tostring(game.lan.allReady),
            game.lan.players.host and tostring(game.lan.players.host.ready) or "nil",
            game.lan.players.guest and tostring(game.lan.players.guest.ready) or "nil"))
        drawButton(game, "Start Match", w * 0.5 - buttonWidth / 2, buttonsY, buttonWidth, buttonHeight, canStart, function()
            print("[LAN UI] Clicked Start Match button!")
            lan_mode.startMatch(game)
        end)
    end
    
    -- Leave room button: all players can click
    drawButton(game, "Leave Room", w * 0.75 - buttonWidth / 2, buttonsY, buttonWidth, buttonHeight, true, function()
        lan_mode.leaveLobby(game)
    end)
end

local function ensureIPInput(game)
    if not game.lanIPInput then
        game.lanIPInput = {
            active = false,
            text = "",
            focused = false,
        }
    end
end

local function drawIPInputField(game, x, y, width, height)
    ensureIPInput(game)
    local input = game.lanIPInput
    love.graphics.setColor(0.9, 0.92, 0.98, 0.9)
    love.graphics.printf("Enter IP address manually:", x, y - 28, width, "left")
    love.graphics.setColor(input.focused and 0.25 or 0.16, input.focused and 0.38 or 0.22, 0.55, 0.95)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", x, y, width, height, 8, 8)
    love.graphics.setColor(0.95, 0.97, 1, 0.95)
    local displayText = input.text
    if displayText == "" then
        love.graphics.setColor(0.6, 0.65, 0.75, 0.7)
        displayText = "e.g. 192.168.1.100"
    end
    love.graphics.printf(displayText, x + 12, y + height / 2 - 10, width - 24, "left")
    if input.focused then
        local cursorX = x + 12 + love.graphics.getFont():getWidth(input.text)
        love.graphics.setColor(0.95, 0.97, 1, 0.9)
        love.graphics.rectangle("fill", cursorX, y + 8, 2, height - 16)
    end
    addZone(game, {x = x, y = y, width = width, height = height, enabled = true, action = function()
        input.focused = true
    end})
end

local function drawJoinView(game)
    local rooms = game.lan.availableRooms or {}
    local w = love.graphics.getWidth()
    local listWidth = math.min(540, w * 0.8)
    local listX = (w - listWidth) / 2
    local startY = love.graphics.getHeight() * 0.35
    
    ensureIPInput(game)
    local input = game.lanIPInput
    
    if #rooms == 0 then
        love.graphics.setColor(0.85, 0.88, 0.96)
        love.graphics.printf("Searching for rooms...", listX, startY, listWidth, "center")
    else
        for index, room in ipairs(rooms) do
            local y = startY + (index - 1) * 70
            local enabled = (room.status or "Waiting") ~= "In Game"
            love.graphics.setColor(0.18, 0.22, 0.32, 0.9)
            love.graphics.rectangle("fill", listX, y, listWidth, 62, 12, 12)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("line", listX, y, listWidth, 62, 12, 12)
            love.graphics.setColor(0.95, 0.97, 1, 0.95)
            love.graphics.printf(string.format("%s (%s)", room.roomId or "Unknown", room.name or room.ip or "Host"),
                listX + 16, y + 12, listWidth * 0.6, "left")
            love.graphics.printf(string.format("%s  %d/%d", room.status or "Waiting", room.players or 1, room.capacity or 2),
                listX, y + 12, listWidth - 20, "right")
            addZone(game, {x = listX, y = y, width = listWidth, height = 62, enabled = enabled, action = function()
                lan_mode.connectToRoom(game, room)
            end})
        end
    end
    
    local inputY = love.graphics.getHeight() * 0.58
    local inputHeight = 48
    drawIPInputField(game, listX, inputY, listWidth, inputHeight)
    
    local buttonWidth, buttonHeight = 220, 50
    local connectButtonY = inputY + inputHeight + 12
    drawButton(game, "Connect", listX + listWidth - buttonWidth, connectButtonY, buttonWidth, buttonHeight, true, function()
        if input.text and input.text ~= "" then
            local success = lan_mode.connectByIP(game, input.text)
            if success then
                input.text = ""
                input.focused = false
            end
        end
    end)
    local buttonsY = love.graphics.getHeight() * 0.78
    drawButton(game, "Refresh List", w * 0.4 - buttonWidth, buttonsY, buttonWidth, buttonHeight, true, function()
        lan_mode.openJoinList(game)
    end)
    drawButton(game, "Back", w * 0.6, buttonsY, buttonWidth, buttonHeight, true, function()
        input.focused = false
        lan_mode.leaveLobby(game)
    end)
end

function lan_scene.initialize(game)
    clearZones(game)
end

function lan_scene.draw(game)
    clearZones(game)
    love.graphics.setColor(0.08, 0.09, 0.12, 0.98)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(0.95, 0.96, 0.99)
    love.graphics.setFont(game.fonts.title or game.fonts.primary)
    love.graphics.printf("LAN Mode", 0, love.graphics.getHeight() * 0.18, love.graphics.getWidth(), "center")
    love.graphics.setFont(game.fonts.primary)

    local view = game.lan and game.lan.view or "menu"
    if view == "menu" then
        love.graphics.printf("Please choose to create or join a room", 0, love.graphics.getHeight() * 0.28, love.graphics.getWidth(), "center")
        drawMenuView(game)
    elseif view == "host" then
        love.graphics.printf("Players in room:", love.graphics.getWidth() * 0.15, love.graphics.getHeight() * 0.28, love.graphics.getWidth() * 0.7, "left")
        drawHostView(game)
    elseif view == "join" then
        love.graphics.printf("Choose a room to join:", love.graphics.getWidth() * 0.15, love.graphics.getHeight() * 0.28, love.graphics.getWidth() * 0.7, "left")
        drawJoinView(game)
    end

    local status = game.lan and game.lan.status or "idle"
    local message = (game.lan and game.lan.message) or "Not connected."
    love.graphics.setColor(0.8, 0.83, 0.92, 0.9)
    love.graphics.printf(string.format("Current status: %s\n%s", status, message),
        love.graphics.getWidth() * 0.15,
        love.graphics.getHeight() * 0.82,
        love.graphics.getWidth() * 0.7,
        "center")
end

function lan_scene.handleClick(game, x, y)
    ensureIPInput(game)
    local input = game.lanIPInput
    local clickedZone = false
    
    if not game.lanClickZones then
        return false
    end
    for _, zone in ipairs(game.lanClickZones) do
        if zone.enabled and utils.pointInRect(zone, x, y) then
            if zone.action then
                zone.action()
            end
            clickedZone = true
            break
        end
    end
    
    if game.lan and game.lan.view == "join" then
        if not clickedZone then
            input.focused = false
        end
    end
    
    return clickedZone
end

local function removeLastChar(str)
    if not str or str == "" then
        return ""
    end
    local utf8 = require("utf8")
    local byteoffset = utf8.offset(str, -1)
    if byteoffset then
        return str:sub(1, byteoffset - 1)
    end
    return ""
end

function lan_scene.handleKey(game, key)
    local view = game.lan and game.lan.view or "menu"
    ensureIPInput(game)
    local input = game.lanIPInput
    
    if view == "join" and input.focused then
        if key == "backspace" then
            input.text = removeLastChar(input.text)
            return true
        elseif key == "return" or key == "kpenter" then
            if input.text and input.text ~= "" then
                local success = lan_mode.connectByIP(game, input.text)
                if success then
                    input.text = ""
                    input.focused = false
                end
            end
            return true
        elseif key == "escape" then
            input.focused = false
            return true
        end
    end
    
    if key == "escape" and view ~= "menu" then
        if input.focused then
            input.focused = false
            return true
        end
        lan_mode.leaveLobby(game)
        return true
    elseif key == "f5" and view == "menu" then
        lan_mode.runLoopbackTest(game)
        return true
    end
    return false
end

function lan_scene.handleTextInput(game, text)
    ensureIPInput(game)
    local input = game.lanIPInput
    if game.lan and game.lan.view == "join" and input.focused then
        -- Only allow digits and dots
        if text:match("^[%d%.]$") then
            input.text = (input.text or "") .. text
        else
            -- If invalid characters are typed (such as Chinese), show a hint but do not add them to the input box
            game.lan.message = "IP address can only contain digits and dots. Please enter something like 192.168.1.100"
        end
        return true
    end
    return false
end

return lan_scene

