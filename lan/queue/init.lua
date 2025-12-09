local Queue = {}
Queue.__index = Queue

function Queue.new()
    return setmetatable({first = 0, last = -1, data = {}}, Queue)
end

function Queue:push(value)
    local last = self.last + 1
    self.last = last
    self.data[last] = value
end

function Queue:pop()
    local first = self.first
    if first > self.last then
        return nil
    end
    local value = self.data[first]
    self.data[first] = nil
    self.first = first + 1
    return value
end

function Queue:isEmpty()
    return self.first > self.last
end

return Queue


