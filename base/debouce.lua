--- 防抖延迟
-- @module Debounce
local Debounce = {}
Debounce.__index = Debounce

--- 初始化
function Debounce:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        last = opts.init or 0, -- 初始值
        delay = opts.delay or 50, -- 消抖时间ms
        event = opts.event, -- 事件
        on_change = opts.on_change, -- 回调
        new = nil,
        id = nil
    }, self)
    return obj
end

function Debounce:on_timeout()
    self.id = nil
    self.last = self.new
    if self.event and #self.event > 0 then
        iot.emit(self.event, self.last)
    end
    if self.on_change then
        self.on_change(self.last)
    end
end

--- 更新值
-- @param value integer 电平
function Debounce:update(value)
    if self.last == value then
        if self.id then
            iot.clearTimeout(self.id)
            self.id = nil
        end
    else
        self.new = value
        self.id = iot.setTimeout(self.on_timeout, self.delay, self)
    end
end

--- 获取值
-- @return integer 电平
function Debounce:value()
    return self.last
end

return Debounce
