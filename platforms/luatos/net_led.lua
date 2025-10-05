local led = {}

local tag = "net-led"

local NET_PIN = 1 -- 默认GPIO 1

local function turn(onoff)
    gpio.set(NET_PIN, onoff and 1 or 0)
end

local function blink(on, off)
    gpio.set(NET_PIN, 1)
    iot.sleep(on)
    if off > 0 then
        gpio.set(NET_PIN, 0)
        iot.sleep(off)
    end
end

iot.started(function()
    gpio.setup(1, 0)

    while true do
        local status = mobile.status()
        if status == mobile.UNREGISTER then
            blink(1000, 1000)
        elseif status == mobile.SEARCH then
            blink(100, 100)
        elseif status == mobile.REGISTERED then
            blink(1000, 0) -- 注册成功
        elseif status == mobile.DENIED then
            blink(1000, 2000)
        elseif status == mobile.UNKNOW then
            blink(1000, 3000)
        elseif status == mobile.REGISTERED_ROAMING then
            blink(1000, 0) -- 漫游
        elseif status == mobile.SMS_ONLY_REGISTERED then
            blink(1000, 4000)
        elseif status == mobile.SMS_ONLY_REGISTERED_ROAMING then
            blink(1000, 5000)
        elseif status == mobile.EMERGENCY_REGISTERED then
            blink(1000, 6000)
        end

    end
end)

return led
