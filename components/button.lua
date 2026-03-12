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
    local this = self

    self.gpio = iot.gpio(self.pin, {
        rising = self.rising,
        falling = self.falling,
        debounce = self.debounce,
        callback = function(id, level)
            -- 反转信号（如果设置了反转）
            if this.reverse then
                level = level > 0 and 0 or 1
            end

            this.state = (level == 1) -- 按钮按下时状态为 true
            log.info("button", id, this.state, this.name)

            if this.disabled then
                return
            end

            if this.state then
                -- 按钮被按下，记录时间
                this.press_start_time = mcu.ticks()
            else
                -- 按钮被松开，判断是否是长按
                local press_duration = mcu.ticks() - this.press_start_time
                if press_duration >= this.long_press_threshold then
                    iot.emit("PRESS", {
                        pin = id,
                        name = this.name
                    })
                else
                    iot.emit("CLICK", {
                        pin = id,
                        name = this.name
                    })
                end
            end

            -- 广播统一事件
            iot.emit("BUTTON", {
                pin = id,
                name = this.name,
                state = this.state,
                level = level
            })

            -- 发送特定事件
            if this.event then
                iot.emit(this.event, this.state)
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
end

--- 禁用按钮
function Button:disable()
    log.info("disable", self.pin, self.name)
    self.disabled = true
end

return Button
