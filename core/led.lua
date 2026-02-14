local tag = "led"

local Led = {}
Led.__index = Led

function Led:new(pin)
    local led = setmetatable({
        pin = pin,
        gpio = iot.gpio(pin),
        blinking = false,
    }, Led)
    return led
end

-- 亮
function Led:on()
    self.gpio:set(1)
    self.blinking = false
end

-- 灭
function Led:off()
    self.gpio:set(0)
    self.blinking = false
end

function Led:set(onOff)    
    self.gpio:set(onOff and 1 or 0)
    self.blinking = false
end

-- 闪烁
function Led:blink(on, off)
    self.blinkOn = on or 500
    self.blinkOff = off or self.blinkOn -- 默认亮灭同样时间

    log.info(tag, "blink start", self.blinkOn, self.blinkOff)

    -- 已经在闪烁就不用再创建协程了
    if self.blinking then
        return
    end

    iot.start(function()

        self.blinking = true

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

        log.info(tag, "blink finish", self.pin)
    end)
end

return Led