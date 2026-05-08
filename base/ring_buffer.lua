--- 环形缓冲区（Ring Buffer）
-- @module RingBuffer

local RingBuffer = {}
RingBuffer.__index = RingBuffer

------------------------------------------------
-- 创建
--
-- @param size number 固定容量
------------------------------------------------
function RingBuffer:new(size)

    assert(size and size > 0, "size must > 0")

    local obj = {
        size = size,
        data = {},
        head = 1,   -- 读指针
        tail = 1,   -- 写指针
        count = 0   -- 当前数量
    }

    setmetatable(obj, self)

    return obj
end

------------------------------------------------
-- 是否为空
------------------------------------------------
function RingBuffer:empty()
    return self.count == 0
end

------------------------------------------------
-- 是否已满
------------------------------------------------
function RingBuffer:full()
    return self.count == self.size
end

------------------------------------------------
-- 当前长度
------------------------------------------------
function RingBuffer:length()
    return self.count
end

------------------------------------------------
-- 入队（push）
--
-- 返回：
-- true  成功
-- false 满了
------------------------------------------------
function RingBuffer:push(value)

    -- 满了：默认丢弃最旧数据（工业常用策略）
    if self.count == self.size then

        -- 覆盖 head
        self.data[self.tail] = value

        self.head = self.tail + 1

        if self.head > self.size then
            self.head = 1
        end

        self.tail = self.head

        return true
    end

    self.data[self.tail] = value

    self.tail = self.tail + 1

    if self.tail > self.size then
        self.tail = 1
    end

    self.count = self.count + 1

    return true
end

------------------------------------------------
-- 出队（pop）
------------------------------------------------
function RingBuffer:pop()

    if self.count == 0 then
        return nil
    end

    local value = self.data[self.head]

    self.data[self.head] = nil

    self.head = self.head + 1

    if self.head > self.size then
        self.head = 1
    end

    self.count = self.count - 1

    return value
end

------------------------------------------------
-- 查看队首
------------------------------------------------
function RingBuffer:peek()

    if self.count == 0 then
        return nil
    end

    return self.data[self.head]
end

------------------------------------------------
-- 清空
------------------------------------------------
function RingBuffer:clear()

    for i = 1, self.size do
        self.data[i] = nil
    end

    self.head = 1
    self.tail = 1
    self.count = 0
end

------------------------------------------------
-- 遍历（调试用）
------------------------------------------------
function RingBuffer:items()

    local i = 0
    local idx = self.head

    return function()

        if i >= self.count then
            return nil
        end

        local value = self.data[idx]

        idx = idx + 1

        if idx > self.size then
            idx = 1
        end

        i = i + 1

        return value
    end
end

------------------------------------------------
-- 转 table（调试用）
------------------------------------------------
function RingBuffer:toTable()

    local t = {}
    local idx = self.head

    for i = 1, self.count do

        t[i] = self.data[idx]

        idx = idx + 1

        if idx > self.size then
            idx = 1
        end
    end

    return t
end

------------------------------------------------
-- 调试信息
------------------------------------------------
function RingBuffer:info()

    return {
        size = self.size,
        count = self.count,
        head = self.head,
        tail = self.tail,
        free = self.size - self.count
    }
end

return RingBuffer