--- 组件 呼吸灯
-- @module BreathLed
local BreathLed = {}
BreathLed.__index = BreathLed

require("components").register("breath_led", BreathLed)

local log = iot.logger("BreathLed")

--- 初始化
function BreathLed:new(opts)
    opts = opts or {}
    local led = setmetatable({
        pin = opts.pin,
        pwm_id = opts.pwm_id,
        freq = opts.freq or 1000, -- PWM频率
        duty_min = opts.duty_min or 0, -- 最暗
        duty_max = opts.duty_max or 100, -- 最亮
        step = opts.step or 1, -- 每次亮度变化步长
        interval = opts.interval or 20, -- ms
        pwm = nil,
        running = false,
        duty = 0
    }, BreathLed)

    return led
end

--- 打开PWM
function BreathLed:open()
    if self.pwm then
        return true
    end

    local ret, pwm = iot.pwm(self.pwm_id, {
        freq = self.freq,
        duty = self.duty_min
    })

    if not ret then
        log.error("PWM打开失败 ", self.pwm_id)
        return false
    end

    self.pwm = pwm
    pwm:start()
    self.duty = self.duty_min

    return true
end

--- 关闭PWM
function BreathLed:close()
    self.running = false
    if self.pwm then
        self.pwm:stop()
        self.pwm = nil
    end
end

--- 启动呼吸灯
function BreathLed:start()
    if not self:open() then
        return false
    end

    if self.running then
        return
    end

    self.running = true

    iot.start(function()
        local direction = 1 -- 1 亮起，-1 变暗
        while self.running do
            self.duty = self.duty + direction * self.step
            if self.duty >= self.duty_max then
                self.duty = self.duty_max
                direction = -1
            elseif self.duty <= self.duty_min then
                self.duty = self.duty_min
                direction = 1
            end

            self.pwm:setDuty(self.duty)
            iot.sleep(self.interval)
        end
        log.info("呼吸灯停止", self.pin)
    end)
end

--- 停止呼吸灯
function BreathLed:stop()
    self.running = false
end

--- 设置亮度区间
function BreathLed:setRange(minDuty, maxDuty)
    self.duty_min = minDuty or self.duty_min
    self.duty_max = maxDuty or self.duty_max
end

return BreathLed
