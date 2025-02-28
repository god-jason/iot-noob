local tag = "ADC"

local i2c_id = 0
local i2c_speed = i2c.FAST
local pin_adc_power = 0 -- 供电

function open()
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
    local ret = i2c.send(i2c_id, 0x01, "read comand")

    if ret == false then
        return ret
    end

    sys.wait(100) --延迟等待

    i2c.recv(i2c_id, 0x01, 10)

    -- 解析

    return true
end
