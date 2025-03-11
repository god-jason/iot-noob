local tag = "input"

local input = {}

local configs = require("configs")

local default_config = {
    enable = true,
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

local config = {}


--- 初始化输入
function input.init()
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

    --- 初始化
    for i, p in ipairs(config.pins) do
        gpio.setup(p.pin, function(val)
            sys.publish("INPUT", i, val, p.pin)
            log.info(tag, "input", i, val, p.pin)
        end)
    end
end


--- 获取输入状态
--- @return integer 1高电平，0低电平
function input.get(index)
    return gpio.get(config.pins[index].pin)
end

return input
