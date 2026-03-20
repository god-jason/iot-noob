--- 组件 继电器
-- @module Relay
local Relay = {}
Relay.__index = Relay

require("components").register("relay", Relay)

local log = iot.logger("relay")

--- 初始化
function Relay:new(opts)
    opts = opts or {}
    local relay = setmetatable({
        pin = opts.pin,
        reverse = opts.reverse or false,
        gpio = iot.gpio(opts.pin),
        state = false
    }, Relay)
    return relay
end

--- 通
function Relay:on()
    log.info(self.pin, "on")
    self.gpio:set(self.reverse and 0 or 1)
    self.state = true
    if self.on_change then
        pcall(self.on_change, "state", self.state)
    end
end

--- 断
function Relay:off()
    log.info(self.pin, "off")
    self.gpio:set(self.reverse and 1 or 0)
    self.state = false
    if self.on_change then
        pcall(self.on_change, "state", self.state)
    end
end

--- 翻转
function Relay:toggle()
    log.info(self.pin, "toggle")
    self.gpio:toggle()
    self.state = ~self.state
    if self.on_change then
        pcall(self.on_change, "state", self.state)
    end
end

--- 设置
function Relay:set(key, value)
    log.info(self.pin, "set", key, value)

    if key == "state" then
        self.state = value == true or value == 1
        if self.reverse then
            self.gpio:set(self.state and 0 or 1)
        else
            self.gpio:set(self.state and 1 or 0)
        end
    end
end

return Relay
