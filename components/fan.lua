--- 组件 风机
-- @module Fan
local Fan = require("utils").class(require("component"))

require("components").register("fan", Fan)

local Speeder = require("speeder")
local log = iot.logger("Fan")

--- 初始化
function Fan:init()
    self.pwm_id = self.pwm_id
    self.freq = self.freq or 10000
    self.duty_min = self.duty_min or 0
    self.duty_max = self.duty_max or 100
    self.levels = self.levels or 10
    self.smooth = self.smooth or false
    self.smooth_step = self.smooth_step or 2 -- 加速步长，百分比
    self.smooth_interval = self.smooth_interval or 10 -- 加速间隔ms
    self.pin = self.pin
    self.gpio = iot.gpio(self.pin)
    self.last_duty = 0 -- 上次速度
    self.target_duty = 0

    self.speeder = Speeder:new({
        levels = self.levels,
        min = self.duty_min,
        max = self.duty_max
    })
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

    self:emit("change", {
        running = true
    })

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

    self:emit("change", {
        level = level
    })

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

    self:emit("change", {
        running = false,
        level = 0
    })
end

--- 设置值
function Fan:set(key, value)
    if key == "run" then
        self:speed(value)
    elseif key == "smooth" then
        self.smooth = value
    else
        return false, "Fan组件不支持变量：" .. key
    end
    return true
end

return Fan
