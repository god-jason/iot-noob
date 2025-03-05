-- local LED_NET = gpio.setup(27, 0, gpio.PULLUP)

local led_config = {
    NET = { pin = 27 },
}

function init()
    -- 读取GPIO配置表
    for k, v in pairs(led_config) do
        v['gpio'] = gpio.setup(v.pin, gpio.PULLDOWN)
    end   
end

function init(id)
    local led = led_config[id]
    if led ~= nil then
        led['gpio'](1)
    end
end

function close(id)
    local led = led_config[id]
    if led ~= nil then
        led['gpio'](0)
    end
end
