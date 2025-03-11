--- LED相关
--- @module "led"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
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

--- LED初始化
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

    -- 初始化网络灯 netLed库 有问题
    -- if config.pins.net then
    --     require("netLed").setup(true, config.pins.net, 0)
    -- end
end

---点亮LED
---@param id string 名称
function led.on(id)
    gpio.set(config.pins[id], gpio.PULLUP)
end

---关闭LED
---@param id string 名称
function led.off(id)
    gpio.set(config.pins[id], gpio.PULLDOWN)
end

return led