--- 组件 蜂鸣器
-- @module Buzzer
local Buzzer = {}
Buzzer.__index = Buzzer

require("components").register("buzzer", Buzzer)

local log = iot.logger("buzzer")

--- 实例化
function Buzzer:new(opts)
    opts = opts or {}
    local buzzer = setmetatable({
        pin = opts.pin, -- GPIO
        pwm_id = opts.pwm_id, -- 如果使用 PWM 控制音量
        freq = opts.freq or 2000, -- 默认频率 2kHz
        duty = opts.duty or 50, -- 默认占空比（PWM）
        pwm = nil,
        ringing = false
    }, Buzzer)

    if opts.pin and opts.pin > 0 then
        buzzer.gpio = iot.gpio(opts.pin)
    end

    return buzzer
end

--- 打开蜂鸣器
function Buzzer:on()
    self:stop() -- 停止任何协程

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
function Buzzer:off()
    self:stop()

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
        for i = 1, times do
            if not self.ringing then
                break
            end
            self:on()
            iot.sleep(on_ms)

            if not self.ringing then
                break
            end
            self:off()
            iot.sleep(off_ms)
        end

        self.ringing = false
    end)
end

--- 停止
function Buzzer:stop()
    self:off()
    self.ringing = false
end

--- 设置 PWM 音量（占空比）
function Buzzer:setDuty(duty)
    self.duty = math.max(0, math.min(100, duty))
    if self.pwm then
        self.pwm:setDuty(self.duty)
    end
end

--- 设置频率
function Buzzer:setFreq(freq)
    self.freq = freq
    if self.pwm then
        self.pwm:setFreq(self.freq)
    end
end

return Buzzer
