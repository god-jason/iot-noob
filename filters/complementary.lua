local Complementary = {}
Complementary.__index = Complementary

function Complementary:new(alpha, init)
    local self = setmetatable({}, Complementary)
    self.alpha = alpha or 0.98
    self.angle = init or 0
    return self
end

function Complementary:update(gyro, acc, dt)
    self.angle = self.alpha * (self.angle + gyro * dt) + (1 - self.alpha) * acc
    return self.angle
end

return Complementary
