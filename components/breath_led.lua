--- 组件 呼吸灯
-- @module BreathLed
local BreathLed = require("utils").class(require("component"))

require("components").register("breath_led", BreathLed)

local log = iot.logger("BreathLed")

--- 初始化
function BreathLed:init()
    self.pwm_id = self.pwm_id
    self.freq = self.freq or 1000 -- PWM频率
    self.duty_min = self.duty_min or 0 -- 最暗
    self.duty_max = self.duty_max or 100 -- 最亮
    self.step = self.step or 1 -- 每次亮度变化步长
    self.interval = self.interval or 20 -- ms
    self.pwm = nil
    self.running = false
    self.duty = 0
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

        self.emit("change", {
            running = true
        })

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

        self.emit("change", {
            running = false
        })
    end)
end

--- 停止呼吸灯
function BreathLed:stop()
    self.running = false
end

--- 设置
function BreathLed:set(key, value)
    if key == "run" then
        if value then
            self:start()
        else
            self:stop()
        end
    elseif key == "duty_min" then
        self.duty_min = value
    elseif key == "duty_max" then
        self.duty_max = self.duty_max
    else
        return false, "未支持的组件参数"
    end
    return true
end

function BreathLed:get(key)
    if key == "running" then
        return true, self.running
    else
        return false, "未支持的组件参数"
    end
end

return BreathLed
