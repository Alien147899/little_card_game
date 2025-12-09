local layout_debugger = {}

local defaultColor = { 0.2, 0.7, 1.0, 0.3 }
local highlightColor = { 1.0, 0.9, 0.2, 0.6 }
local activeColor = { 0.98, 0.4, 0.1, 0.65 }

layout_debugger.enabled = false
layout_debugger.frameNodes = {}
layout_debugger.nodes = {}
layout_debugger.activeNodeId = nil
layout_debugger.hoveredNodeId = nil
layout_debugger.dragging = nil
layout_debugger.statusText = nil
layout_debugger.statusTimer = 0

local defaultFields = { x = "x", y = "y", width = "width", height = "height" }

local function cloneFields(fields)
    local clone = {}
    for key, value in pairs(fields or defaultFields) do
        clone[key] = value
    end
    return clone
end

local function setStatus(text)
    layout_debugger.statusText = text
    layout_debugger.statusTimer = 2.0
end

function layout_debugger.load()
    layout_debugger.enabled = false
    layout_debugger.frameNodes = {}
    layout_debugger.nodes = {}
    layout_debugger.activeNodeId = nil
    layout_debugger.hoveredNodeId = nil
    layout_debugger.dragging = nil
    layout_debugger.statusText = nil
    layout_debugger.statusTimer = 0
end

function layout_debugger.toggle()
    layout_debugger.enabled = not layout_debugger.enabled
    layout_debugger.dragging = nil
    if layout_debugger.enabled then
        setStatus("Layout debugger enabled (F4 to export)")
    else
        setStatus("Layout debugger disabled")
    end
end

function layout_debugger.beginFrame()
    layout_debugger.frameNodes = {}
end

function layout_debugger.registerRect(id, target, opts)
    if not target or not id then
        return
    end

    layout_debugger.frameNodes = layout_debugger.frameNodes or {}

    local fields = cloneFields(opts and opts.fields or defaultFields)
    local node = {
        id = id,
        target = target,
        fields = fields,
        category = (opts and opts.category) or "rect",
        color = (opts and opts.color) or defaultColor,
        draggable = (opts and opts.draggable) ~= false,
        x = target[fields.x] or 0,
        y = target[fields.y] or 0,
        width = target[fields.width] or (opts and opts.width) or 0,
        height = target[fields.height] or (opts and opts.height) or 0,
    }

    table.insert(layout_debugger.frameNodes, node)
end

local function getNodeById(id)
    if not id then
        return nil
    end
    for _, node in ipairs(layout_debugger.nodes or {}) do
        if node.id == id then
            return node
        end
    end
    return nil
end

local function findNodeAt(x, y)
    for index = #layout_debugger.nodes, 1, -1 do
        local node = layout_debugger.nodes[index]
        if x >= node.x and x <= (node.x + node.width)
            and y >= node.y and y <= (node.y + node.height) then
            return node
        end
    end
    return nil
end

local function applyPosition(target, fields, newX, newY)
    if not target or not fields then
        return
    end
    if fields.x then
        target[fields.x] = newX
    end
    if fields.y then
        target[fields.y] = newY
    end
end

local function applySize(target, fields, width, height)
    if not target or not fields then
        return
    end
    if fields.width and width then
        target[fields.width] = math.max(1, width)
    end
    if fields.height and height then
        target[fields.height] = math.max(1, height)
    end
end

function layout_debugger.update(_, dt)
    if layout_debugger.statusTimer > 0 then
        layout_debugger.statusTimer = math.max(0, layout_debugger.statusTimer - dt)
        if layout_debugger.statusTimer == 0 then
            layout_debugger.statusText = nil
        end
    end
end

local function drawNode(node)
    local color = node.color or defaultColor
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.rectangle("fill", node.x, node.y, node.width, node.height)

    local outline = { color[1], color[2], color[3], 1 }
    love.graphics.setColor(outline)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", node.x, node.y, node.width, node.height)

    local label = node.id or "node"
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", node.x, node.y - 22, node.width, 22)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(
        string.format("%s  (%.0f, %.0f)", label, node.x, node.y),
        node.x + 4,
        node.y - 20,
        node.width - 8,
        "left"
    )

    if node.id == layout_debugger.activeNodeId then
        love.graphics.setColor(activeColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", node.x - 3, node.y - 3, node.width + 6, node.height + 6)
    elseif node.id == layout_debugger.hoveredNodeId then
        love.graphics.setColor(highlightColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", node.x - 2, node.y - 2, node.width + 4, node.height + 4)
    end
end

function layout_debugger.draw(game)
    layout_debugger.nodes = layout_debugger.frameNodes or {}

    if not layout_debugger.enabled then
        return
    end

    local mx, my = love.mouse.getPosition()
    local hovered = findNodeAt(mx, my)
    layout_debugger.hoveredNodeId = hovered and hovered.id or nil

    love.graphics.setColor(0.05, 0.08, 0.1, 0.55)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    for _, node in ipairs(layout_debugger.nodes) do
        drawNode(node)
    end

    if layout_debugger.statusText then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle(
            "fill",
            0,
            love.graphics.getHeight() - 36,
            love.graphics.getWidth(),
            36
        )
        love.graphics.setColor(0.96, 0.98, 1, 0.95)
        love.graphics.printf(
            layout_debugger.statusText,
            12,
            love.graphics.getHeight() - 30,
            love.graphics.getWidth() - 24,
            "left"
        )
    end

    love.graphics.setColor(0.96, 0.98, 1, 0.65)
    love.graphics.printf(
        "F3 toggle | F4 export | Mouse drag / arrow keys move | [ / ] width  ; / ' height",
        0,
        12,
        love.graphics.getWidth(),
        "center"
    )
end

function layout_debugger.mousepressed(_, x, y, button)
    if not layout_debugger.enabled then
        return false
    end

    if button == 1 then
        local node = findNodeAt(x, y)
        if node then
            layout_debugger.activeNodeId = node.id
            if node.draggable then
                layout_debugger.dragging = {
                    target = node.target,
                    fields = node.fields,
                    offsetX = x - node.x,
                    offsetY = y - node.y,
                }
            end
            return true
        else
            layout_debugger.activeNodeId = nil
            layout_debugger.dragging = nil
            return true
        end
    elseif button == 2 then
        layout_debugger.activeNodeId = nil
        layout_debugger.dragging = nil
        return true
    end

    return false
end

function layout_debugger.mousemoved(_, x, y, dx, dy)
    if not layout_debugger.enabled then
        return false
    end

    if layout_debugger.dragging then
        local drag = layout_debugger.dragging
        local newX = x - drag.offsetX
        local newY = y - drag.offsetY
        applyPosition(drag.target, drag.fields, newX, newY)
        return true
    end

    return false
end

function layout_debugger.mousereleased(_, _, button)
    if not layout_debugger.enabled then
        return false
    end

    if button == 1 and layout_debugger.dragging then
        layout_debugger.dragging = nil
        return true
    end

    return false
end

local function adjustActiveNode(deltaX, deltaY, deltaW, deltaH)
    local node = getNodeById(layout_debugger.activeNodeId)
    if not node then
        return
    end

    local target = node.target
    local fields = node.fields

    if deltaX ~= 0 or deltaY ~= 0 then
        local newX = (target[fields.x] or node.x or 0) + deltaX
        local newY = (target[fields.y] or node.y or 0) + deltaY
        applyPosition(target, fields, newX, newY)
    end

    if deltaW ~= 0 or deltaH ~= 0 then
        local newW = (target[fields.width] or node.width or 0) + deltaW
        local newH = (target[fields.height] or node.height or 0) + deltaH
        applySize(target, fields, newW, newH)
    end
end

function layout_debugger.exportLayout()
    if not layout_debugger.nodes or #layout_debugger.nodes == 0 then
        setStatus("No nodes available to export")
        return
    end

    local lines = { "return {" }
    for _, node in ipairs(layout_debugger.nodes) do
        lines[#lines + 1] = string.format(
            "    [\"%s\"] = { x = %.2f, y = %.2f, width = %.2f, height = %.2f },",
            node.id,
            node.x,
            node.y,
            node.width,
            node.height
        )
    end
    lines[#lines + 1] = "}"
    local payload = table.concat(lines, "\n")

    local okWrite = false
    if love.filesystem then
        love.filesystem.createDirectory("layout_presets")
        local filename = string.format("layout_presets/export_%s.lua", os.date("%Y%m%d_%H%M%S"))
        local success = love.filesystem.write(filename, payload)
        if success then
            okWrite = true
            print(string.format(
                "[LayoutDebugger] Exported layout to %s/%s",
                love.filesystem.getSaveDirectory(),
                filename
            ))
        end
    end

    local clipboardOk = false
    if love.system and love.system.setClipboardText then
        local ok, _ = pcall(function()
            love.system.setClipboardText(payload)
        end)
        clipboardOk = ok
    end

    if clipboardOk then
        setStatus("Layout exported and copied to clipboard")
    elseif okWrite then
        setStatus("Layout exported to file")
    else
        setStatus("Export failed: unable to write file")
    end
end

function layout_debugger.keypressed(_, key)
    if key == "f3" then
        layout_debugger.toggle()
        return true
    end

    if key == "f4" then
        if layout_debugger.enabled then
            layout_debugger.exportLayout()
            return true
        end
        return false
    end

    if not layout_debugger.enabled then
        return false
    end

    local step = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 1

    if key == "left" then
        adjustActiveNode(-step, 0, 0, 0)
        return true
    elseif key == "right" then
        adjustActiveNode(step, 0, 0, 0)
        return true
    elseif key == "up" then
        adjustActiveNode(0, -step, 0, 0)
        return true
    elseif key == "down" then
        adjustActiveNode(0, step, 0, 0)
        return true
    elseif key == "[" then
        adjustActiveNode(0, 0, -step, 0)
        return true
    elseif key == "]" then
        adjustActiveNode(0, 0, step, 0)
        return true
    elseif key == ";" then
        adjustActiveNode(0, 0, 0, -step)
        return true
    elseif key == "'" then
        adjustActiveNode(0, 0, 0, step)
        return true
    end

    return false
end

return layout_debugger

