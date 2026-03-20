--- 组件 指示灯
-- @module Led
local Led = {}
Led.__index = Led

require("components").register("led", Led)

local log = iot.logger("led")

--- 初始化
function Led:new(opts)
    opts = opts or {}
    local led = setmetatable({
        pin = opts.pin,
        gpio = iot.gpio(opts.pin),
        blinking = false
    }, Led)
    return led
end

--- 亮
function Led:on()
    self.gpio:set(1)
    self.blinking = false

    if self.on_change then
        pcall(self.on_change, "state", true)
    end
end

--- 灭
function Led:off()
    self.gpio:set(0)
    self.blinking = false

    if self.on_change then
        pcall(self.on_change, "state", false)
    end
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

        if self.on_change then
            pcall(self.on_change, "blinking", self.blinking)
        end

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

        if self.on_change then
            pcall(self.on_change, "blinking", self.blinking)
        end
    end)

    if self.on_change then
        pcall(self.on_change, "state", true)
    end
end

--- 开关
function Led:set(key, value)
    if key == "state" then
        self.gpio:set((value == true or value == 1) and 1 or 0)
        self.blinking = false
    elseif key == "blink" then
        self:blink(value)
    end
end

return Led
