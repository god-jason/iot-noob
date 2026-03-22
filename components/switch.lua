--- 组件 开关
-- @module Switch
local Switch = require("utils").class(require("component"))

require("components").register("switch", Switch)

local log = iot.logger("Switch")

--- 初始化
function Switch:init()
    self.pin = self.pin
    self.name = self.name
    self.reverse = self.reverse or false
    self.rising = self.rising or false
    self.falling = self.falling or false
    self.debounce = self.debounce or 50
    self.state = false
    self.event = self.event
    self.callback = self.callback

    self.gpio = iot.gpio(self.pin, {
        rising = self.rising,
        falling = self.falling,
        debounce = self.debounce,
        callback = function(level, id)
            -- 反转
            if self.reverse then
                level = level > 0 and 0 or 1
            end

            self.state = (level == 1)

            -- log.info("switch", id, level, self.name, self.event)

            if self.disabled then
                return
            end

            -- 回调
            if type(self.callback) == "function" then
                local ok, err = pcall(self.callback, level)
                if not ok then
                    log.error("switch callback error:", err)
                end
            end

            -- 发送统一事件
            iot.emit("SWITCH", {
                pin = id,
                name = self.name,
                event = self.event,
                level = level
            })

            -- 发送特定事件
            if self.event then
                iot.emit(self.event, level)
            end

            self:emit("change", {
                state = self.state
            })
        end
    })
end

--- 设置
function Switch:set(key, value)
    log.info(self.pin, "set", key, value)

    if key == "disabled" then
        self.disabled = value == true
    else
        return false, "Switch组件不支持变量：" .. key
    end
    return true
end

function Switch:get(key)
    if key == "state" then
        return true, self.state
    elseif key == "disabled" then
        return true, self.disabled
    else
        return false, "Switch组件不支持变量：" .. key
    end
end

return Switch
