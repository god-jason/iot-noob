--- LED相关
--- @module "led"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "led"
local led = {}

local default_options = {
    enable = true,
    pins = {
        net = 27,
        ready = 26,
        -- cloud = 
        -- power = 49 -- 待定
    }
}

local options = {}

--- LED初始化
function led.init(opts)

    log.info(tag, "init")
    
    -- 加载配置
    options = opts or default_options

    if not options.enable then
        return
    end


    -- 读取GPIO配置表
    for k, v in pairs(options.pins) do
        gpio.setup(v, 0, gpio.PULLDOWN)
    end

    -- 初始化网络灯 netLed库 有问题
    -- if options.pins.net then
    --     require("netLed").setup(true, options.pins.net, 0)
    -- end
end

---点亮LED
---@param id string 名称
function led.on(id)
    gpio.set(options.pins[id], 1)
end

---关闭LED
---@param id string 名称
function led.off(id)
    gpio.set(options.pins[id], 0)
end

return led