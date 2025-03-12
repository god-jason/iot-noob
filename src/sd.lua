--- sd/tf卡相关
--- @module "sd"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "sd"
local sd = {}

local configs = require("configs")

local default_config = {
    enable = true, -- 启用
    spi = 1, -- SPI
    cs_pin = 2, -- 片选GPIO
    speed = 24000000 -- 速度，默认 10000000
}

local config = {}

--- 初始化config卡
function sd.init()
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

    spi.setup(config.spi, 255, 0, 0, 8, 4000000)

    gpio.setup(config.cs_pin, 1)
    -- fatfs.debug(1)

    fatfas.mount(fatfs.SPI, "SD", config.spi, config.cs_pin, config.speed)

end

---格式化config卡
---@return boolean 成功与否
function sd.format()
    if not config.enable then
        return false
    end
    return io.mkfs("/sd")
end

return sd
