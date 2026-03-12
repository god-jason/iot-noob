--- IIR滤波器
-- @module IIR
local IIR = {}
IIR.__index = IIR

function IIR:new(alpha, init)
    local obj = setmetatable({}, IIR)
    obj.alpha = alpha or 0.1
    obj.y = init or 0
    return obj
end

--- 更新数据
-- @param x
function IIR:update(x)
    self.y = self.alpha * x + (1 - self.alpha) * self.y
    return self.y
end

return IIR
