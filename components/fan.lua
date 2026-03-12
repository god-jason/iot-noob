--- 组件 风机
-- @module Fan
local Fan = {}
Fan.__index = Fan

require("components").register("fan", Fan)

local Speeder = require("speeder")
local log = iot.logger("fan")

--- 初始化
function Fan:new(opts)
    opts = opts or {}
    local fan = setmetatable({
        pwm_id = opts.pwm_id,
        levels = opts.levels or 10,
        freq = opts.freq or 10000,
        duty_min = opts.duty_min or 0,
        duty_max = opts.duty_max or 100,
        smooth = opts.smooth or false,
        smooth_step = opts.smooth_step or 2, -- 加速步长，百分比
        smooth_interval = opts.smooth_interval or 10, -- 加速间隔ms
        pin = opts.pin,
        gpio = iot.gpio(opts.pin),
        last_duty = 0, -- 上次速度
        target_duty = 0
    }, Fan)
    fan.speeder = Speeder:new({
        levels = fan.levels,
        min = fan.duty_min,
        max = fan.duty_max
    })
    return fan
end

--- 打开
-- @param level 风级
function Fan:open(level)
    local ret, pwm = iot.pwm(self.pwm_id, {
        freq = self.freq,
        duty = self.duty_min
    })
    if ret then
        self.pwm = pwm
        pwm:start()
    end

    -- 如果PWM坏了，则全速运行
    self.gpio:set(1)

    if level and level > 0 then
        self:speed(level)
    end

    return ret
end

--- 加速
function Fan:accelerate(start)
    self.accelerating = true

    -- 此处没有考虑降档，实测风机自然降档效果也可以
    while start < self.target_duty do
        start = start + self.smooth_step
        self.pwm:setDuty(start)
        iot.sleep(self.smooth_interval)
    end
    self.pwm:setDuty(self.target_duty)

    self.accelerating = false
end

--- 设置风速
-- @param level 风级
-- @param immediate 立即，不加速
function Fan:speed(level, immediate)
    if not self.pwm then
        self:open()
    end
    if not self.pwm then
        return false, "PWM未打开"
    end

    -- local duty = self:calc_duty(level)
    local duty = math.floor(self.speeder:calc(level))

    -- 不平滑，直接处理
    if not self.smooth or immediate then
        self.pwm:setDuty(duty)
        return true
    end

    -- 设定目标速度，由线程执行
    self.target_duty = duty

    -- 启动线程逐级加速
    if not self.accelerating then
        iot.start(Fan.accelerate, self, self.last_duty)
    end

    self.last_duty = duty

    return true
end

--- 关闭
function Fan:close()
    self.last_duty = 0
    self.target_duty = 0

    self.gpio:set(0)
    if self.pwm then
        self.pwm:stop()
        self.pwm = nil
    end
end

return Fan
