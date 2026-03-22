--- 组件 继电器
-- @module Relay
local Relay = require("utils").class(require("component"))

require("components").register("relay", Relay)

local log = iot.logger("Relay")

--- 初始化
function Relay:init()
    self.pin = self.pin
    self.reverse = self.reverse or false
    self.gpio = iot.gpio(self.pin)
    self.state = false
end

--- 通
function Relay:turn_on()
    log.info(self.pin, "turn_on")
    self.gpio:set(self.reverse and 0 or 1)
    self.state = true
    self:emit("change", {
        state = self.state
    })
end

--- 断
function Relay:turn_off()
    log.info(self.pin, "turn_off")
    self.gpio:set(self.reverse and 1 or 0)
    self.state = false
    self:emit("change", {
        state = self.state
    })
end

--- 翻转
function Relay:toggle()
    log.info(self.pin, "toggle")
    self.gpio:toggle()
    self.state = ~self.state
    self:emit("change", {
        state = self.state
    })
end

--- 设置
function Relay:set(key, value)
    log.info(self.pin, "set", key, value)

    if key == "state" then
        if value then
            self:turn_on()
        else
            self:turn_off()
        end
    else
        return false, "Relay组件不支持变量：" .. key
    end
    return true
end

function Relay:get(key)
    if key == "state" then
        return true, self.state
    else
        return false, "Relay组件不支持变量：" .. key
    end
end

return Relay
