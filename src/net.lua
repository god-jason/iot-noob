local netLed = require("netLed")
local tag = "NET"
local net = {}

function net.init()
    local led = gpio.setup(LEDS.net, 1, gpio.PULLUP)
    netLed.setup(true, LEDS.net, 0) -- 780不再支持LTE灯    
end

function net.status()
    local ret = mobile.scell()
    ret['csq'] = mobile.csq()
    return ret
end

function net.ready()
    return mobile.status() == 1 --网络已经注册
end

return net
