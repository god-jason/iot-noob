--- IO输出相关
--- @module "output"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "output"
local output = {}

local default_options = {
    enable = false,
    pins = {{
        name = "Y1",
        pin = 30,
        value = 1,
        pull = 1
    }, {
        name = "Y2",
        pin = 31
    }, {
        name = "Y3",
        pin = 32
    }}
}

local options = {}

--- 初始化输出
function output.init(opts)

    log.info(tag, "init")

    -- 加载配置
    options = opts or default_options

    if not options.enable then
        return
    end

    -- 初始化GPIO
    for i, p in ipairs(options.pins) do
        gpio.setup(p.pin, p.value or 0, p.pull or gpio.PULLDOWN)
    end

end

--- 设置输出
--- @param index string 名称
--- @param value integer 1 0
function output.set(index, value)
    if not options.enable then
        return
    end

    local p = options.pins[index]
    gpio.set(p.pin, value)
    log.info(tag, "output", index, value, p.pin)
end

return output
