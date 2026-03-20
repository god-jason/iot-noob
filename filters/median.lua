--- 中值滤波器（优化版）
-- @module Median
local Median = {}
Median.__index = Median

require("filters").register("median", Median)

local log = iot.logger("median")

function Median:new(opts)
    opts = opts or {}
    local size = opts.size or 3

    local obj = setmetatable({
        size = size,
        buffer = {},
        index = 1,
        count = 0
    }, Median)

    -- 预分配
    for i = 1, size do
        obj.buffer[i] = 0
    end

    return obj
end

--- 更新
function Median:update(val)
    if val == nil then return self:get() end

    -- 写入环形缓冲
    self.buffer[self.index] = val

    self.index = self.index + 1
    if self.index > self.size then
        self.index = 1
    end

    if self.count < self.size then
        self.count = self.count + 1
    end

    -- 拷贝有效数据
    local tmp = {}
    for i = 1, self.count do
        tmp[i] = self.buffer[i]
    end

    table.sort(tmp)

    local mid = math.floor(self.count / 2) + 1
    return tmp[mid]
end

--- 获取当前值
function Median:get()
    if self.count == 0 then return 0 end

    local tmp = {}
    for i = 1, self.count do
        tmp[i] = self.buffer[i]
    end

    table.sort(tmp)
    local mid = math.floor(self.count / 2) + 1
    return tmp[mid]
end

--- 重置
function Median:reset(val)
    self.index = 1
    self.count = 0

    for i = 1, self.size do
        self.buffer[i] = val or 0
    end

    if val then
        self.count = self.size
    end
end

return Median