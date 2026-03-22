--- 组件 变速器
-- @module Speeder
local Speeder = require("utils").class(require("component"))

require("components").register("speeder", Speeder)

--- 创建变速器
function Speeder:init()
    self.name = self.name or "-"
    self.levels = self.levels or 10
    self.min = self.min or 0
    self.max = self.max or 100
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
