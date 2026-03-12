local log = iot.logger("servo")

--- 组件 舵机
-- @module Servo
local Servo = {}
Servo.__index = Servo

require("components").register("servo", Servo)

--- 创建舵机
function Servo:new(opts)
    opts = opts or {}
    local servo = setmetatable({
        pwm_id = opts.pwm_id,
        freq = 50, -- 固定50Hz
        min_angle = opts.min_angle or 0,
        max_angle = opts.max_angle or 180,
        min_pulse = opts.min_pulse or 0.5, -- ms
        max_pulse = opts.max_pulse or 2.5 -- ms
    }, Servo)
    servo:init()
    return servo
end

--- 初始化
function Servo:init()
    -- pwm.setup(self.pwm, self.freq, Servo:angle_to_duty(90)) -- 默认90° 7.5
    -- pwm.start(self.pwm)
    local ret, pwm = iot.pwm(self.pwm_id, {
        freq = self.freq,
        duty = Servo:angle_to_duty(90)
    })
    if ret then
        self.pwm = pwm
        pwm:start()
    end
    return ret
end

function Servo:angle_to_duty(angle)
    local pulse = self.min_pulse + (angle - self.min_angle) * (self.max_pulse - self.min_pulse) /
                      (self.max_angle - self.min_angle)

    local duty = pulse / 20 * 100
    return duty
end

--- 设置角度
-- @param angle 角度
function Servo:set(angle)
    angle = math.max(self.min_angle, math.min(self.max_angle, angle))

    local duty = self:angle_to_duty(angle)
    -- pwm.setDuty(self.pwm, duty)
    self.pwm:setDuty(duty)

    self.current_angle = angle
end

--- 停止
function Servo:stop()
    -- pwm.stop(self.pwm)
    self.pwm:stop()
end

return Servo
