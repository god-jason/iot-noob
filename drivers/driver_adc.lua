--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 外部adc芯片接口
-- @module ADC驱动
local adc_ext = {}

local tag = "adc_ext"

local configs = require("configs")

local default_options = {
    enable = false,
    chip = "AD7616", -- 型号
    spi = 2, -- spi总线
    cs_pin = 10, -- spi片选引脚
    channels = 16, -- 通道数量
    bits = 16, -- 精度 10->1023 12->4095 14->16383 16->65535 20->1048575 24->16777215
    init = {0x00, 0x00}, -- 初始化指令
    read = {0x00}, -- 读取指令
    power_pin = 10, -- 供电GPIO
    enable_pin = 11, -- 使能GPIO
    reset_pin = 12, -- 复位GPIO
    busy_pin = 13 -- 忙检测GPIO
}

local options = {}

-- ADC芯片初始化
function adc_ext.init()
    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    log.info(tag, "init")

    if type(options.init) == "string" then
        options.init = string.fromHex(options.init)
    end
    if type(options.read) == "string" then
        options.read = string.fromHex(options.read)
    end

    -- 开启供电
    if options.power_pin ~= nil then
        gpio.setup(options.power_pin, gpio.PULLUP)
    end

    -- 初始化spi接口
    local ret = spi.setup(options.spi, options.cs_pin)
    if ret ~= 0 then
        log.info(tag, "open spi ", ret)
        return
    end

    -- 使能
    -- gpio.setup(options.enable_pin, gpio.PULLUP)

    -- 初始化指令
    spi.send(options.spi, options.init)
end

--- 关闭ADC芯片
function adc_ext.close()
    spi.close(options.spi)

    if options.power_pin ~= nil then
        gpio.setup(options.power_pin, gpio.PULLDOWN)
    end
end

--- 读取ADC数据
function adc_ext.read()
    -- 重置
    gpio.setup(options.reset_pin, gpio.PULLUP)

    -- 发送读指令
    spi.send(options.spi, options.read)
    -- sys.wait(100) --延迟等待

    local len = 2 * options.channels
    if options.bits > 16 then
        len = 2 * len
    end

    -- 读取数据
    local data = spi.recv(options.spi, len)
    if data == nil then
        return false
    end

    -- 解析
    if options.bits > 16 then
        local values = {pack.unpack(data, ">i" .. options.channels)}
        table.remove(values, 1)
        return true, values
    else
        local values = {pack.unpack(data, ">h" .. options.channels)}
        table.remove(values, 1)
        return true, values
    end
end

-- 启动
adc_ext.init()

return adc_ext
