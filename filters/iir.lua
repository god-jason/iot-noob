--- 通用 IIR 滤波器（支持多阶）
-- @module IIR
local IIR = {}
IIR.__index = IIR

require("filters").register("iir", IIR)

function IIR:new(opts)
    opts = opts or {}

    local obj = setmetatable({
        -- 系数
        b = opts.b or {1},   -- 前向系数
        a = opts.a or {1},   -- 反馈系数（a[1] 应为1）

        -- 历史数据
        x = {},
        y = {},

        order = 0
    }, IIR)

    obj.order = math.max(#obj.b, #obj.a)

    -- 初始化历史数据
    for i = 1, obj.order do
        obj.x[i] = 0
        obj.y[i] = 0
    end

    return obj
end

--- 更新
function IIR:update(input)
    -- 移动历史数据
    for i = self.order, 2, -1 do
        self.x[i] = self.x[i - 1]
        self.y[i] = self.y[i - 1]
    end

    self.x[1] = input

    -- 计算输出
    local output = 0

    -- 前向部分
    for i = 1, #self.b do
        output = output + self.b[i] * (self.x[i] or 0)
    end

    -- 反馈部分（从2开始）
    for i = 2, #self.a do
        output = output - self.a[i] * (self.y[i] or 0)
    end

    self.y[1] = output
    return output
end

--- 重置
function IIR:reset(val)
    for i = 1, self.order do
        self.x[i] = val or 0
        self.y[i] = val or 0
    end
end

return IIR