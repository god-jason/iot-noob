--- 中值滤波器
-- @module Median
local Median = {}
Median.__index = Median

function Median:new(size)
    local obj = setmetatable({}, Median)
    obj.size = size or 3
    obj.buffer = {}
    return obj
end

--- 更新数据
-- @param val
function Median:update(val)
    table.insert(self.buffer, val)
    if #self.buffer > self.size then
        table.remove(self.buffer, 1)
    end
    local tmp = {table.unpack(self.buffer)}
    table.sort(tmp)
    local mid = math.floor(#tmp / 2) + 1
    return tmp[mid]
end

return Median
