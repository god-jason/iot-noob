--- 组件 舵机
-- @module Servo
local Servo = require("utils").class(require("component"))

require("components").register("servo", Servo)

local log = iot.logger("Servo")

--- 创建舵机
function Servo:init()
    self.pwm_id = self.pwm_id
    self.freq = 50 -- 固定50Hz
    self.min_angle = self.min_angle or 0
    self.max_angle = self.max_angle or 180
    self.min_pulse = self.min_pulse or 0.5 -- ms
    self.max_pulse = self.max_pulse or 2.5 -- ms

    -- pwm.setup(self.pwm, self.freq, Servo:angle_to_duty(90)) -- 默认90° 7.5
    -- pwm.start(self.pwm)
    local ret, pwm = iot.pwm(self.pwm_id, {
        freq = self.freq,
        duty = Servo:angle_to_duty(90)
    })
    if ret then
        self.pwm = pwm
        pwm:start()
    else
        log.error("PWM打开失败", pwm)
    end
end

function Servo:angle_to_duty(angle)
    local pulse = self.min_pulse + (angle - self.min_angle) * (self.max_pulse - self.min_pulse) /
                      (self.max_angle - self.min_angle)

    local duty = pulse / 20 * 100
    return duty
end

--- 设置角度
-- @param angle 角度
function Servo:angle(angle)
    angle = math.max(self.min_angle, math.min(self.max_angle, angle))

    local duty = self:angle_to_duty(angle)
    -- pwm.setDuty(self.pwm, duty)
    self.pwm:setDuty(duty)

    self.current_angle = angle

    self:emit("change", {
        angle = angle
    })
end

--- 停止
function Servo:stop()
    -- pwm.stop(self.pwm)
    self.pwm:stop()
end

--- 设置值
function Servo:set(key, value)
    if key == "angle" then
        self:angle(value)
    else
        return false, "Led组件不支持变量：" .. key
    end
    return true
end

function Servo:get(key)
    if key == "angle" then
        return true, self.current_angle
    else
        return false, "Led组件不支持变量：" .. key
    end
end


return Servo
