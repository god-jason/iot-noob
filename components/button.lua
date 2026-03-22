--- 组件 按钮
-- @module Button
local Button = require("utils").class(require("component"))

require("components").register("button", Button)

local log = iot.logger("Button")

function Button:init()
    self.pin = self.pin -- 按钮连接的 GPIO 引脚
    self.name = self.name -- 名称
    self.event = self.event -- 事件
    self.reverse = self.reverse or false -- 是否反转信号
    self.rising = self.rising or false -- 上升沿触发
    self.falling = self.falling or false -- 下降沿触发
    self.debounce = self.debounce or 50 -- 防抖时间（毫秒）
    self.state = false -- 按钮当前状态（true=按下，false=松开）
    self.press_start_time = nil -- 按下开始时间
    self.long_press_threshold = self.long_press_threshold or 3000 -- 长按时间阈值（默认3秒）

    self.gpio = iot.gpio(self.pin, {
        rising = self.rising,
        falling = self.falling,
        debounce = self.debounce,
        callback = function(level, id)
            -- 反转信号（如果设置了反转）
            if self.reverse then
                level = level > 0 and 0 or 1
            end

            self.state = (level == 1) -- 按钮按下时状态为 true
            log.info("button", id, self.state, self.name)

            if self.disabled then
                return
            end

            if self.state then
                -- 按钮被按下，记录时间
                self.press_start_time = mcu.ticks()
            elseif self.press_start_time then
                -- 按钮被松开，判断是否是长按
                local press_duration = mcu.ticks() - self.press_start_time
                if press_duration >= self.long_press_threshold then
                    iot.emit("PRESS", {
                        pin = id,
                        name = self.name
                    })
                else
                    iot.emit("CLICK", {
                        pin = id,
                        name = self.name
                    })
                end
                self.press_start_time = nil
            end

            -- 广播统一事件
            iot.emit("BUTTON", {
                pin = id,
                name = self.name,
                state = self.state,
                level = level
            })

            -- 发送特定事件
            if self.event then
                iot.emit(self.event, self.state)
            end

            self:emit("change", {
                state = self.state
            })
        end
    })
end

--- 获取当前按钮状态（按下或松开）
function Button:status()
    return self.state
end

--- 启用按钮
function Button:enable()
    log.info("enable", self.pin, self.name)
    self.disabled = false

    self:emit("change", {
        disabled = self.disabled
    })
end

--- 禁用按钮
function Button:disable()
    log.info("disable", self.pin, self.name)
    self.disabled = true

    self:emit("change", {
        disabled = self.disabled
    })
end

--- 设置值
function Button:set(key, value)
    if key == "disabled" then
        self.disabled = value == true
    else
        return false, "Button组件不支持变量：" .. key
    end
    return true
end

function Button:get(key)
    if key == "disabled" then
        return true, self.disabled
    elseif key == "state" then
        return true, self.state
    else
        return false, "Button组件不支持变量：" .. key
    end
end

return Button
