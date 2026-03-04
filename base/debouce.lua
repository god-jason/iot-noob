local Debounce = {}
Debounce.__index = Debounce

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
        self.on_change(self.last, self.last)
    end
end

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

function Debounce:value()
    return self.last
end

return Debounce
