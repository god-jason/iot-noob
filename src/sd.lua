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
    enable = false, -- 启用
    spi = 1, -- SPI
    cs_pin = 2, -- 片选GPIO
    speed = 24000000 -- 速度，默认 10000000
}

local config = {}

--- 初始化SD卡
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

    spi.setup(SD.spi, 255, 0, 0, 8, 4000000)

    gpio.setup(SD.cs_pin, 1)
    -- fatfs.debug(1)

    fatfas.mount(fatfs.SPI, "SD", SD.spi, SD.cs_pin, SD.speed)

end

---格式化SD卡
---@return boolean 成功与否
function sd.format()
    if not config.enable then
        return false
    end
    return io.mkfs("/sd")
end

return sd
