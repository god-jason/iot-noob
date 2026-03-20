--- 组件 按钮
-- @module Button
local Button = {}
Button.__index = Button

require("components").register("button", Button)

local log = iot.logger("button")

--- 构造函数
function Button:new(opts)
    opts = opts or {}
    local button = setmetatable({
        pin = opts.pin, -- 按钮连接的 GPIO 引脚
        name = opts.name, -- 名称
        event = opts.event, -- 事件
        reverse = opts.reverse or false, -- 是否反转信号
        rising = opts.rising or false, -- 上升沿触发
        falling = opts.falling or false, -- 下降沿触发
        debounce = opts.debounce or 50, -- 防抖时间（毫秒）
        state = false, -- 按钮当前状态（true=按下，false=松开）
        press_start_time = nil, -- 按下开始时间
        long_press_threshold = opts.long_press_threshold or 3000 -- 长按时间阈值（默认3秒）
    }, Button)
    button:init()
    return button
end

--- 初始化按钮
function Button:init()

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

            if self.on_change then
                pcall(self.on_change, "state", self.state)
            end
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

    if self.on_change then
        pcall(self.on_change, "disabled", false)
    end
end

--- 禁用按钮
function Button:disable()
    log.info("disable", self.pin, self.name)
    self.disabled = true

    if self.on_change then
        pcall(self.on_change, "disabled", true)
    end
end

--- 设置值
function Button:set(key, value)
    if key == "disabled" then
        self.disabled = value == true
    end
end

return Button
