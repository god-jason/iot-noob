--- 一维卡尔曼滤波器（增强版）
-- @module Kalman
local Kalman = {}
Kalman.__index = Kalman

require("filters").register("kalman", Kalman)

local log = iot.logger("kalman")

function Kalman:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        -- 状态
        x = opts.x or 0,     -- 当前估计值
        P = opts.P or 1,     -- 估计误差

        -- 噪声
        Q = opts.Q or 0.01,  -- 过程噪声
        R = opts.R or 1,     -- 测量噪声

        -- 可选模型
        F = opts.F or 1,     -- 状态转移
        B = opts.B or 0,     -- 控制矩阵
        u = opts.u or 0      -- 控制输入

    }, Kalman)

    return obj
end

--- 更新
-- @param z 测量值
-- @param u 控制输入（可选）
function Kalman:update(z, u)
    -- 预测
    u = u or self.u
    self.x = self.F * self.x + self.B * u
    self.P = self.F * self.P * self.F + self.Q

    -- 卡尔曼增益
    local K = self.P / (self.P + self.R)

    -- 更新
    self.x = self.x + K * (z - self.x)
    self.P = (1 - K) * self.P

    return self.x, K, self.P
end

--- 设置Q/R（动态调参）
function Kalman:set_noise(Q, R)
    if Q then self.Q = Q end
    if R then self.R = R end
end

--- 重置
function Kalman:reset(x, P)
    self.x = x or 0
    self.P = P or 1
end

--- 获取当前状态
function Kalman:get()
    return self.x
end

return Kalman