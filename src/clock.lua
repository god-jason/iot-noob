-- 时钟芯片暂未选定
local tag = "clock"
local clock = {}

local function bcd_to_hex(data)
    return bit.rshift(data, 4) * 10 + bit.band(data, 0x0f)
end

local function hex_to_bcd(data)
    return bit.lshift(math.floor(data / 10), 4) + data % 10
end

local configs = require("configs")

local default_config = {
    enable = true,
    chip = "SD3077", -- 型号
    i2c = 1, -- iic总线
    addr = 0x64, -- 站号 0x64: SD3077, 0x68 SD3231
    init = {0x0E, 0x04}, -- 初始化 关闭clock输出
    read = {0x00}, -- 读指令
    write = {0x00}, -- 写指令
    registers = { -- 寄存器
    0x00, -- 首地址
    "second", "minute", "hour", "wday", "day", "month", "year"}

}

local config = {}

function clock.init()
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

    -- 初始化iic接口
    i2c.setup(config.i2c, i2c.FAST)

    -- 初始化指令
    if config.init ~= nil and #config.init > 0 then
        i2c.send(config.i2c, config.addr, config.init)
    end

    -- 读取config芯片时钟
    sys.timerStart(read, 500)
end

function clock.read()
    if not config.enable then
        return false
    end

    -- 发送
    local ret = i2c.send(config.i2c, config.addr, config.registers[1]) -- 从秒开始读
    if ret == false then
        return ret
    end

    -- 读取
    local data = i2c.recv(config.i2c, config.addr, 7)

    -- 解析
    local time = {}
    for i, v in ipairs(config.registers) do
        if v == "year" then
            time.year = bcd_to_hex(data:byte(i - 1)) + 2000
        elseif v == "month" then
            time.mon = bcd_to_hex(bit.band(data:byte(i - 1), 0x7f)) - 1
        elseif v == "day" then
            time.day = bcd_to_hex(data:byte(i - 1))
        elseif v == "wday" then
            time.wday = bcd_to_hex(data:byte(i - 1)) + 1
        elseif v == "hour" then
            time.hour = bcd_to_hex(bit.band(data:byte(i - 1), 0x7f)) -- 最高位代表 24小时制
        elseif v == "minute" then
            time.min = bcd_to_hex(data:byte(i - 1))
        elseif v == "second" then
            time.sec = bcd_to_hex(data:byte(i - 1))
        end
    end

    -- 设置到系统中
    local r = rtc.set(time)
    log.info(tag, "set time", r, json.encode(time))

    return true, time
end

function clock.write()
    if not config.enable then
        return false
    end

    -- local tm = socket.ntptm()
    local tm = os.date("*t")

    local data = { config.registers[1] }
    for i, v in ipairs(config.registers) do
        if v == "year" then
            table.insert(data, hex_to_bcd(tm.year - 2000))
        elseif v == "month" then
            table.insert(data, hex_to_bcd(tm.month))
        elseif v == "day" then
            table.insert(data, hex_to_bcd(tm.day))
        elseif v == "wday" then
            table.insert(data, hex_to_bcd(tm.wday - 1))
        elseif v == "hour" then
            table.insert(data, hex_to_bcd(tm.hour))
        elseif v == "minute" then
            table.insert(data, hex_to_bcd(tm.min))
        elseif v == "second" then
            table.insert(data, hex_to_bcd(tm.sec))
        end
    end

    -- 写指令
    local ret = i2c.send(config.i2c, config.addr, data)
    log.info(tag, "write time", ret, json.encode(tm))

    return ret
end

return clock
