--- 组件 指示灯
-- @module Led
local Led = require("utils").class(require("component"))

require("components").register("led", Led)

local log = iot.logger("Led")

--- 初始化
function Led:init()
    self.pin = self.pin
    self.gpio = iot.gpio(self.pin)
    self.state = false
    self.blinking = false
end

--- 亮
function Led:turn_on()
    self.gpio:set(1)
    self.state = true
    self.blinking = false

    self:emit("change", {
        state = state
    })
end

--- 灭
function Led:turn_off()
    self.gpio:set(0)
    self.state = false
    self.blinking = false

    self:emit("change", {
        state = state
    })
end

--- 闪烁
function Led:blink(on, off)
    self.blinkOn = on or 500
    self.blinkOff = off or self.blinkOn -- 默认亮灭同样时间

    log.info("blink start", self.blinkOn, self.blinkOff)

    -- 已经在闪烁就不用再创建协程了
    if self.blinking then
        return
    end

    iot.start(function()
        self.blinking = true

        self:emit("change", {
            blinking = self.blinking
        })

        while self.blinking do

            -- 亮
            self.gpio:set(1)
            iot.sleep(self.blinkOn)
            if not self.blinking then
                break
            end

            -- 灭
            self.gpio:set(0)
            iot.sleep(self.blinkOff)
        end

        log.info("blink finish", self.pin)

        self:emit("change", {
            blinking = self.blinking
        })
    end)

    self:emit("change", {
        state = true
    })
end

--- 开关
function Led:set(key, value)
    if key == "state" then
        if value then
            self:turn_on()
        else
            self:turn_off()
        end
    elseif key == "blink" then
        self:blink(value)
    else
        return false, "Led组件不支持变量：" .. key
    end
    return true
end

function Led:get(key)
    return false, "Led组件不支持变量：" .. key
end

return Led
