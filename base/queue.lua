--- 高性能队列
-- @module Queue

local Queue = {}
Queue.__index = Queue

------------------------------------------------
-- 创建队列
--
-- @param max number 最大长度
--        0 = 不限制
------------------------------------------------
function Queue:new(max)

    local obj = {
        first = 1,
        last = 0,
        max = max or 0,
        data = {}
    }

    setmetatable(obj, self)

    return obj
end

------------------------------------------------
-- 当前长度
------------------------------------------------
function Queue:size()
    return self.last - self.first + 1
end

------------------------------------------------
-- 是否为空
------------------------------------------------
function Queue:empty()
    return self.first > self.last
end

------------------------------------------------
-- 入队
--
-- 默认策略：
-- 队列满时丢弃最旧数据（drop oldest）
--
-- @param value any
-- @return boolean
------------------------------------------------
function Queue:push(value)

    ------------------------------------------------
    -- 队列长度限制
    ------------------------------------------------

    if self.max > 0 and self:size() >= self.max then
        self:pop()
    end

    ------------------------------------------------
    -- 入队
    ------------------------------------------------

    local last = self.last + 1

    self.last = last

    self.data[last] = value

    return true
end

------------------------------------------------
-- 出队
--
-- @return any
------------------------------------------------
function Queue:pop()

    if self.first > self.last then
        return nil
    end

    local first = self.first

    local value = self.data[first]

    -- 释放引用
    self.data[first] = nil

    self.first = first + 1

    ------------------------------------------------
    -- 队列清空
    ------------------------------------------------

    if self.first > self.last then

        self.first = 1
        self.last = 0

    ------------------------------------------------
    -- 长时间运行后的索引压缩
    ------------------------------------------------

    elseif self.first > 100000 then

        local newData = {}

        local j = 1

        for i = self.first, self.last do
            newData[j] = self.data[i]
            j = j + 1
        end

        self.data = newData

        self.first = 1
        self.last = j - 1
    end

    return value
end

------------------------------------------------
-- 查看队首
--
-- @return any
------------------------------------------------
function Queue:peek()

    if self.first > self.last then
        return nil
    end

    return self.data[self.first]
end

------------------------------------------------
-- 清空队列
------------------------------------------------
function Queue:clear()

    for i = self.first, self.last do
        self.data[i] = nil
    end

    self.first = 1
    self.last = 0
end

------------------------------------------------
-- 遍历
--
-- 用法:
--
-- for item in q:items() do
--     print(item)
-- end
------------------------------------------------
function Queue:items()

    local i = self.first - 1

    return function()

        i = i + 1

        if i <= self.last then
            return self.data[i]
        end
    end
end

------------------------------------------------
-- 转数组（调试用）
------------------------------------------------
function Queue:toTable()

    local t = {}

    local j = 1

    for i = self.first, self.last do
        t[j] = self.data[i]
        j = j + 1
    end

    return t
end

------------------------------------------------
-- 队列信息（调试）
------------------------------------------------
function Queue:info()

    return {
        first = self.first,
        last = self.last,
        size = self:size(),
        max = self.max
    }
end

return Queue