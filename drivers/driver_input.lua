--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- IO输入相关
-- @module 开关输入
local input = {}

local tag = "input"

local configs = require("configs")

local default_options = {
    enable = false,
    pins = {{
        pin = 27,
        name = "X1"
    }, {
        pin = 28,
        name = "X2"
    }, {
        pin = 29,
        name = "X3"
    }}
}

local options = {}

--- 初始化输入
function input.init()
    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    log.info(tag, "init")

    -- 初始化
    for i, p in ipairs(options.pins) do
        gpio.setup(p.pin, function(val)
            sys.publish("INPUT", i, val, p.pin)
            log.info(tag, "input", i, val, p.pin)
        end)
    end
end

--- 获取输入状态
-- @return integer 1高电平，0低电平
function input.get(index)
    return gpio.get(options.pins[index].pin)
end

-- 启动
input.init()

return input
