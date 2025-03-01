--- ADC芯片接口
-- @module analog
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.03.01
-- 基于AD7616芯片开发，其他芯片需要做参数调整

local tag = "ADC"

local i2c_id = 0
local i2c_speed = i2c.FAST
local addr = 0x08 --地址
local reg = 0x00 --寄存器地址


local pin_adc_power = 0 -- 供电

function init()
    -- 开启供电
    if pin_adc_power > 0 then
        gpio.setup(pin_adc_power, gpio.PULLUP)
    end

    -- 初始化iic接口
    local ret = i2c.setup(i2c_id, i2c_speed)
    log.info(tag, "adc init result", ret)

    -- TODO 初始化指令
end

function close()
    i2c.close(i2c_id)

    if pin_adc_power > 0 then
        gpio.set(pin_adc_power, 0)
    end
end

function read()
    -- 发送
    local ret = i2c.send(i2c_id, addr, "read comand")

    if ret == false then
        return ret
    end

    sys.wait(100) --延迟等待

    i2c.recv(i2c_id, addr, 10)

    -- 解析

    return true
end
