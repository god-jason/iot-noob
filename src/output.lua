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
    enable = true,
    pins = {{
        name = "TTL_TXD", --银尔达780 25引脚要拉高，才能输出数据
        pin = 25,
        value = 1,
        pull = 1,
    }, {
        name = "Y1",
        pin = 30,
        value = 1,
        pull = 1,
    }, {
        name = "Y2",
        pin = 31,
    }, {
        name = "Y3",
        pin = 32,
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

    -- 初始化GPIO
    for i, p in ipairs(config.pins) do
        gpio.setup(p.pin, p.value or 0, p.pull or gpio.PULLDOWN)
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
