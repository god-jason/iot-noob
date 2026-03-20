--- 指数滤波器（增强版）
-- @module EMA
local EMA = {}
EMA.__index = EMA

require("filters").register("ema", EMA)

local log = iot.logger("ema")

function EMA:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        alpha = opts.alpha or 0.5,
        last = opts.init,        -- 初始值
        min = opts.min,          -- 可选限幅
        max = opts.max,

        adaptive = opts.adaptive, -- 是否自适应
        threshold = opts.threshold or 10, -- 自适应阈值
        fast_alpha = opts.fast_alpha or 0.8 -- 快速响应
    }, EMA)
    return obj
end

--- 限幅
function EMA:_clamp(v)
    if self.min and v < self.min then return self.min end
    if self.max and v > self.max then return self.max end
    return v
end

--- 更新
function EMA:update(val)
    if val == nil then return self.last end

    val = self:_clamp(val)

    -- 初始化
    if self.last == nil then
        self.last = val
        return val
    end

    local alpha = self.alpha

    -- 自适应滤波（变化大 → 更快响应）
    if self.adaptive then
        if math.abs(val - self.last) > self.threshold then
            alpha = self.fast_alpha
        end
    end

    self.last = alpha * val + (1 - alpha) * self.last
    return self.last
end

--- 重置
function EMA:reset(val)
    self.last = val
end

--- 获取当前值
function EMA:get()
    return self.last
end

return EMA