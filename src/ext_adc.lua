--- 外部cfg芯片接口
--- @module analog
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.01
--- 基于AD7616芯片开发，其他芯片需要做参数调整
local tag = "ext_adc"
local ext_adc = {}

local configs = require("configs")

local default_config = {
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

local config = {}

-- ADC芯片初始化
function ext_adc.init()
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

    -- 开启供电
    if config.power_pin ~= nil then
        gpio.setup(config.power_pin, gpio.PULLUP)
    end

    -- 初始化iic接口
    ret = spi.setup(config.spi, config.cs_pin)
    if ret ~= 0 then
        log.info(tag, "adc init failed", ret)
        return
    end

    -- 使能
    gpio.setup(config.enable_pin, gpio.PULLUP)

    -- 初始化指令
    spi.send(config.spi, config.init)
end


--- 关闭ADC芯片
function ext_adc.close()
    spi.close(config.spi)

    if config.power_pin ~= nil then
        gpio.setup(config.power_pin, gpio.PULLDOWN)
    end
end


--- 读取ADC数据
function ext_adc.read()
    -- 重置
    gpio.setup(config.reset_pin, gpio.PULLUP)

    -- 发送读指令
    spi.send(config.spi, config.read)
    -- sys.wait(100) --延迟等待

    local len = 2 * config.channels
    if config.bits > 16 then
        len = 2 * len
    end

    -- 读取数据
    local data = spi.recv(config.spi, len)
    if data == nil then
        return false
    end

    -- 解析
    if config.bits > 16 then
        local values = {pack.unpack(data, ">i" .. config.channels)}
        table.remove(values, 1)
        return true, values
    else
        local values = {pack.unpack(data, ">h" .. config.channels)}
        table.remove(values, 1)
        return true, values
    end

    return true
end

return ext_adc
