--- 卡尔曼滤波器
-- @module Kalman
local Kalman = {}
Kalman.__index = Kalman

-- 创建卡尔曼滤波器
function Kalman:new(opts)
    opts = opts or {}
    return setmetatable({
        Q = opts.Q or 0.01, -- 过程噪声
        R = opts.R or 1, -- 测量噪声
        P = opts.P or 1, -- 估计误差
        x = opts.x or 0 -- 初始值
    }, Kalman)
end

--- 更新数据
-- @param z
function Kalman:update(z)
    -- 预测
    self.P = self.P + self.Q

    -- 计算卡尔曼增益
    local K = self.P / (self.P + self.R)

    -- 更新估计
    self.x = self.x + K * (z - self.x)

    -- 更新误差
    self.P = (1 - K) * self.P

    return self.x
end

return Kalman
