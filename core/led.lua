--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- LED相关
-- @module LED
local led = {}

local tag = "led"

local configs = require("configs")

local default_options = {
    enable = true,
    pins = {
        net = 27,
        ready = 26
    }
}

local options = {}

--- LED初始化
function led.init()
    log.info(tag, "init")

    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    -- 读取GPIO配置表
    for _, v in pairs(options.pins) do
        gpio.setup(v, 0, gpio.PULLDOWN)
    end

    -- 初始化网络灯 netLed库 有问题
    -- if options.pins.net then
    --     require("netLed").setup(true, options.pins.net, 0)
    -- end
end

---点亮LED
-- @param id string 名称
function led.on(id)
    gpio.set(options.pins[id], 1)
end

---关闭LED
-- @param id string 名称
function led.off(id)
    gpio.set(options.pins[id], 0)
end

-- 启动
led.init()

sys.subscribe("IP_READY", function()
    led.on("net")
end)

sys.subscribe("IP_LOSE", function()
    led.off("net")
end)

return led
