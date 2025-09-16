--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- sd/tf卡相关
-- @module sd
local sd = {}


local tag = "sd"

local configs = require("configs")

local default_options = {
    enable = false, -- 启用 (默认配置有问题，会直接宕机)
    spi = 1, -- SPI
    cs_pin = 2, -- 片选GPIO
    speed = 24000000 -- 速度，默认 10000000
}

local options = {}

--- 初始化config卡
function sd.init()
    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    log.info(tag, "init")

    spi.setup(options.spi, 255, 0, 0, 8, 4000000)

    gpio.setup(options.cs_pin, 1)
    -- fatfs.debug(1)

    fatfs.mount(fatfs.SPI, "SD", options.spi, options.cs_pin, options.speed)

end

---格式化config卡
-- @return boolean 成功与否
function sd.format()
    if not options.enable then
        return false
    end
    return io.mkfs("/sd")
end

-- 启动
sd.init()

return sd
