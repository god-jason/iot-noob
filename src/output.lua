--- IO输出相关
--- @module "output"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "output"
local output = {}

local configs = require("configs")

local default_config = {
    enable = false,
    pins = {{
        pin = 30,
        name = "Y1"
    }, {
        pin = 31,
        name = "Y2"
    }, {
        pin = 32,
        name = "Y3"
    }}
}

local config = {}


--- 初始化输出
function output.init()

    log.info(tag, "init")
    
    -- 加载配置
    config = configs.load_default(tag, default_config)

    if not config.enable then
        return
    end
    
end

--- 设置输出
--- @param index string 名称
--- @param value integer 1 0
function output.set(index, value)
    if not config.enable then
        return
    end

    local p = config.pins[index]
    gpio.set(p.pin, value)
    log.info(tag, "output", index, value, p.pin)
end

return output
