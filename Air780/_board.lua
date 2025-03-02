--- 电路板配置
-- @module main
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.03.02


-- LED配置
LEDS = {
    NET = { pin = 12 },

}


-- 串口配置
SERIALS = {
    { id = 0, name = "RS485", rs485_gpio = 22 },
    { id = 1, name = "RS232", }
}


-- ADC芯片
ADC = {
    chip = "AD7616",       -- 型号
    spi = 2,               -- spi总线
    cs_pin = 10,           -- spi片选引脚
    channels = 16,         -- 通道数量
    bits = 16,             -- 精度 10->1023 12->4095 14->16383 16->65535 20->1048575 24->16777215
    init = { 0x00, 0x00 }, -- 初始化指令
    read = { 0x00 },       -- 读取指令
    power_pin = 10,        -- 供电GPIO
    enable_pin = 11,       -- 使能GPIO
    reset_pin = 12,        -- 复位GPIO
    busy_pin = 13,         -- 忙检测GPIO
    --
}


-- RTC芯片
RTC = {
    chip = "SD3077",       -- 型号
    i2c = 1,               -- iic总线
    addr = 0x64,           -- 站号 0x64: SD3077, 0x68 SD3231
    init = { 0x0E, 0x04 }, -- 初始化 关闭clock输出
    read = { 0x00 },       -- 读指令
    write = { 0x00 },      -- 写指令
    registers = {          -- 寄存器
        0x00, -- 首地址
        "second", "minute", "hour", "wday", "day", "month", "year",
    }
}


-- 输入GPIO
INPUTS = {
    { pin = 27, name = "X1" },
    { pin = 28, name = "X2" },
    { pin = 29, name = "X3" },
}


-- 输出GPIO
OUTPUTS = {
    { pin = 30, name = "Y1" },
    { pin = 31, name = "Y2" },
    { pin = 32, name = "Y3" },
}

-- 电池定义
BATTERY = {
    adc = 1,                   -- 内置ADC 0 1
    bits = 10,                 -- 精度，默认10->1023
    range = adc.ADC_RANGE_1_2, -- 范围
    voltage = 12,              -- 电池电压
    empty = 11.2,              -- 空的电压
    full = 14.2,               -- 满的电压
}
