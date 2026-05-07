--- 队列
-- @module Queue
local Queue = {}
Queue.__index = Queue

-- 创建
function Queue:new(max)
    local obj = {
        first = 1,
        last = 0,
        max = max or 0 -- 0=无限
    }
    setmetatable(obj, self)
    return obj
end

-- 长度
function Queue:size()
    return self.last - self.first + 1
end

-- 是否为空
function Queue:empty()
    return self.first > self.last
end

-- 入队
function Queue:push(value)
    -- 队列长度限制
    if self.max > 0 and self:size() >= self.max then
        return false, "queue full"
    end

    local last = self.last + 1

    self.last = last
    self[last] = value

    return true
end

-- 出队
function Queue:pop()

    local first = self.first

    if first > self.last then
        return nil
    end

    local value = self[first]

    self[first] = nil -- 避免内存泄漏

    self.first = first + 1

    -- 队列清空时重置索引

    if self.first > self.last then
        self.first = 1
        self.last = 0
    end

    return value
end

-- 查看队首
function Queue:peek()

    if self.first > self.last then
        return nil
    end

    return self[self.first]
end

-- 清空
function Queue:clear()

    for i = self.first, self.last do
        self[i] = nil
    end

    self.first = 1
    self.last = 0
end

-- 遍历
function Queue:items()

    local i = self.first - 1

    return function()
        i = i + 1
        if i <= self.last then
            return self[i]
        end
    end
end

return Queue
