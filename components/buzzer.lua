--- 组件 蜂鸣器
-- @module Buzzer
local Buzzer = require("utils").class(require("component"))

require("components").register("buzzer", Buzzer)

local log = iot.logger("Buzzer")

--- 实例化
function Buzzer:init()
    self.pin = self.pin -- GPIO
    self.pwm_id = self.pwm_id -- 如果使用 PWM 控制音量
    self.freq = self.freq or 2000 -- 默认频率 2kHz
    self.duty = self.duty or 50 -- 默认占空比（PWM）
    self.pwm = nil
    self.ringing = false

    self.gpio = iot.gpio(self.pin)
end

--- 打开蜂鸣器
function Buzzer:turn_on()
    if self.gpio then
        self.gpio:set(1)
    end

    -- 打开PWM
    if self.pwm_id then

        local ok, pwm = iot.pwm(self.pwm_id, {
            freq = self.freq,
            duty = self.duty
        })

        if not ok then
            return false, "PWM打开失败" .. self.pwm_id
        end

        self.pwm = pwm
        pwm:start()
    end

    return true
end

--- 关闭蜂鸣器
function Buzzer:turn_off()
    if self.gpio then
        self.gpio:set(0)
    end

    if self.pwm then
        self.pwm:stop()
        self.pwm = nil
    end
end

--- 异步响铃，支持间隔
-- @param times 响铃次数
-- @param on_ms
-- @param off_ms
function Buzzer:ring(times, on_ms, off_ms)
    times = times or 1
    on_ms = on_ms or 500
    off_ms = off_ms or on_ms

    if self.ringing then
        return
    end

    self.ringing = true

    iot.start(function()

        self:emit("change", {
            ringing = self.ringing
        })

        for i = 1, times do
            if not self.ringing then
                break
            end
            self:turn_on()
            iot.sleep(on_ms)

            if not self.ringing then
                break
            end
            self:turn_off()
            iot.sleep(off_ms)
        end

        self:turn_off()
        self.ringing = false

        self:emit("change", {
            ringing = self.ringing
        })
    end)
end

--- 停止
function Buzzer:stop()
    self.ringing = false
end

--- 设置值
function Buzzer:set(key, value)
    if key == "ring" then
        self:ring(key, value)
    elseif key == "duty" then
        self.duty = value
    elseif key == "freq" then
        self.freq = value
    else
        return false, "Buzzer组件不支持变量：" .. key
    end
    return true
end

function Buzzer:get(key)
    if key == "ringing" then
        return true, self.ringing
    elseif key == "duty" then
        return true, self.duty
    elseif key == "freq" then
        return true, self.freq
    else
        return false, "Buzzer组件不支持变量：" .. key
    end
end

return Buzzer
