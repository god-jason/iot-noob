-- 时钟芯片暂未选定
local tag = "RTC"

local i2c_id = 0
local i2c_speed = i2c.FAST -- FAST LOW
local addr = 0x64          -- 芯片地址 0x64: SD3077, 0x68 SD3231

local function bcd_to_hex(data)
    return bit.rshift(data, 4) * 10 + bit.band(data, 0x0f)
end

local function hex_to_bcd(data)
    return bit.lshift(math.floor(data / 10), 4) + data % 10
end

function init()
    -- 初始化iic接口
    i2c.setup(i2c_id, i2c_speed)

    -- TODO 初始化指令
    i2c.send(i2c_id, addr, { 0x0E, 0x04 }) -- 关闭clock输出

    log.info(tag, "rtc init result", ret)

    -- 读取RTC芯片时钟
    sys.timerStart(read, 500)
end

function read()
    -- 发送
    local ret = i2c.send(i2c_id, addr, 0x00) -- 从秒开始读
    if ret == false then
        return ret
    end

    -- 读取
    local data = i2c.recv(i2c_id, addr, 7)

    -- 解析
    local time = {
        year = bcd_to_hex(data:byte(7)) + 2000,
        mon = bcd_to_hex(bit.band(data:byte(6), 0x7f)) - 1,
        day = bcd_to_hex(data:byte(5)),
        wday = bcd_to_hex(data:byte(4)) + 1,
        hour = bcd_to_hex(bit.band(data:byte(3), 0x7f)), -- 最高位代表 24小时制
        min = bcd_to_hex(data:byte(2)),
        sec = bcd_to_hex(data:byte(1))
    }

    -- 设置到系统中
    local r = rtc.set(time)
    log.info(tag, "set time", r, json.encode(time))

    return true, time
end

function write()
    -- local tm = socket.ntptm()
    local tm = os.date("*t")

    -- set time
    local data7 = hex_to_bcd(tm.year - 2000) -- 2025
    local data6 = hex_to_bcd(tm.month)       -- 1-12
    local data5 = hex_to_bcd(tm.day)         -- 1-31
    local data4 = hex_to_bcd(tm.wday - 1)    -- 1-7 日一二三四五六
    local data3 = hex_to_bcd(tm.hour)        -- 0-23
    local data2 = hex_to_bcd(tm.min)         -- 0-59
    local data1 = hex_to_bcd(tm.sec)         -- 0-61 ？？？

    local ret = i2c.send(i2c_id, addr, { 0x00, data1, data2, data3, data4, data5, data6, data7 })
    log.info(tag, "write time", ret, json.encode(tm))
    return ret
end

function temperature()
    local ret = i2c.send(i2c_id, addr, 0x11)
    if ret == false then
        return ret
    end

    -- 读取
    local temp
    local data = i2c.recv(i2c_id, addr, 2)
    if bit.band(data:byte(1), 0x80) then
        -- 负温度
        temp = data:byte(1)
        temp = temp - (bit.rshift(data:byte(2), 6) * 0.25) -- 0.25C resolution
    else
        -- 正温度
        temp = data:byte(1)
        temp = temp + (bit.band(bit.rshift(data:byte(2), 6), 0x03) * 0.25)
    end
    return true, temp
end
