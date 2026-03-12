--- 互补滤波器
-- @module Complementary
local Complementary = {}
Complementary.__index = Complementary

function Complementary:new(alpha, init)
    local obj = setmetatable({}, Complementary)
    obj.alpha = alpha or 0.98
    obj.angle = init or 0
    return obj
end

--- 更新数据
-- @param gyro
-- @param acc
-- @param dt
-- @return 角度
function Complementary:update(gyro, acc, dt)
    self.angle = self.alpha * (self.angle + gyro * dt) + (1 - self.alpha) * acc
    return self.angle
end

return Complementary
