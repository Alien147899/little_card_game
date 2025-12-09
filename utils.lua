-- Utility functions
local utils = {}

function utils.shallowCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

function utils.loadFont(path, size)
    if love.filesystem.getInfo(path) then
        return love.graphics.newFont(path, size)
    end
    return love.graphics.newFont(size)
end

function utils.pointInRect(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height
end

function utils.lerp(current, target, t)
    return current + (target - current) * t
end

function utils.shuffle(deck)
    for i = #deck, 2, -1 do
        local j = love.math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

function utils.removeCardFromList(list, card)
    for idx, value in ipairs(list) do
        if value == card then
            table.remove(list, idx)
            return true, idx
        end
    end
    return false
end

return utils

