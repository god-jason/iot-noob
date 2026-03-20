--- 移动平均滤波器（优化版）
-- @module MA
local MA = {}
MA.__index = MA

require("filters").register("ma", MA)

local log = iot.logger("ma")

function MA:new(opts)
    opts = opts or {}

    local size = opts.size or 5

    local obj = setmetatable({
        size = size,
        buffer = {},
        sum = 0,
        index = 1,
        count = 0
    }, MA)

    -- 初始化缓冲区
    for i = 1, size do
        obj.buffer[i] = 0
    end

    return obj
end

--- 更新
function MA:update(val)
    if val == nil then return self:get() end

    -- 移除旧值
    self.sum = self.sum - self.buffer[self.index]

    -- 写入新值
    self.buffer[self.index] = val
    self.sum = self.sum + val

    -- 更新索引（环形）
    self.index = self.index + 1
    if self.index > self.size then
        self.index = 1
    end

    -- 计数
    if self.count < self.size then
        self.count = self.count + 1
    end

    return self.sum / self.count
end

--- 获取当前值
function MA:get()
    if self.count == 0 then return 0 end
    return self.sum / self.count
end

--- 重置
function MA:reset(val)
    self.sum = 0
    self.index = 1
    self.count = 0

    for i = 1, self.size do
        self.buffer[i] = val or 0
    end

    if val then
        self.sum = val * self.size
        self.count = self.size
    end
end

return MA