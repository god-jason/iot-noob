local tag = "output"
local output = {}

local configs = require("configs")

local default_config = {
    enable = true,
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

function output.init()
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
end

function output.set(index, value)
    if not config.enable then
        return
    end

    local p = config.pins[index]
    gpio.set(p.pin, value)
    log.info(tag, "output", index, value, p.pin)
end

return output
