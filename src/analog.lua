--- ADC芯片接口
--- @module analog
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.01
--- 基于AD7616芯片开发，其他芯片需要做参数调整

local tag = "ADC"
local analog = {}


function analog.init()
    -- 开启供电
    if ADC.power_pin ~= nil then
        gpio.setup(ADC.power_pin, gpio.PULLUP)
    end

    -- 初始化iic接口
    local ret = spi.setup(ADC.spi, ADC.cs_pin)
    if ret ~= 0 then
        log.info(tag, "adc init failed", ret)
        return
    end

    -- 使能
    gpio.setup(ADC.enable_pin, gpio.PULLUP)

    -- 初始化指令
    spi.send(ADC.spi, ADC.init)
end

function analog.close()
    spi.close(ADC.spi)

    if ADC.power_pin ~= nil then
        gpio.setup(ADC.power_pin, gpio.PULLDOWN)
    end
end

function analog.read()
    -- 重置
    gpio.setup(ADC.reset_pin, gpio.PULLUP)

    -- 发送读指令
    spi.send(ADC.spi, ADC.read)
    -- sys.wait(100) --延迟等待

    local len = 2 * ADC.channels
    if ADC.bits > 16 then
        len = 2 * len
    end

    -- 读取数据
    local data = spi.recv(ADC.spi, len)
    if data == nil then return false end

    -- 解析
    if ADC.bits > 16 then
        local values = { pack.unpack(data, ">i" .. ADC.channels) }
        table.remove(values, 1)
        return true, values
    else
        local values = { pack.unpack(data, ">h" .. ADC.channels) }
        table.remove(values, 1)
        return true, values
    end

    return true
end


return analog