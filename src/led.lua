local tag = "led"
local led = {}

local configs = require("configs")

local default_config = {
    enable = true,
    pins = {
        net = 27,
        ready = 26
        -- power = 49 -- 待定
    }
}

local config = {}

function led.init()
    local ret

    -- 加载配置
    ret, config = configs.load(tag)
    if not ret then
        -- 使用默认
        config = default_config
    end

    if not config.enable then
        return
    end

    log.info(tag, "init")

    -- 读取GPIO配置表
    -- for k, v in pairs(config.pins) do
    --     v['gpio'] = gpio.setup(v.pin, gpio.PULLDOWN)
    -- end

    -- 初始化网络灯
    if config.pins.net then
        require("netLed").setup(true, config.pins.net, 0)
    end
end

function led.on(id)
    gpio.set(config.pins[id], gpio.PULLUP)
end

function led.off(id)
    gpio.set(config.pins[id], gpio.PULLDOWN)
end

return led