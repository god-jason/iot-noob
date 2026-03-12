--- 组件 变速器
-- @module Speeder
local Speeder = {}
Speeder.__index = Speeder

require("components").register("speeder", Speeder)

--- 创建变速器
function Speeder:new(opts)
    opts = opts or {}
    return setmetatable({
        name = opts.name or "-",
        levels = opts.levels or 10,
        min = opts.min or 0,
        max = opts.max or 100
    }, Speeder)
end

--- 计算变速值（脉冲频率，占空比等）
-- @param level 等级
function Speeder:calc(level)
    if level < 0 then
        level = 0
    elseif level > self.levels then
        level = self.levels
    end
    return self.min + level / self.levels * (self.max - self.min)
end

return Speeder
