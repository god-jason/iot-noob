-- 时钟芯片暂未选定
local tag = "RTC"
local clock = {}

local function bcd_to_hex(data)
    return bit.rshift(data, 4) * 10 + bit.band(data, 0x0f)
end

local function hex_to_bcd(data)
    return bit.lshift(math.floor(data / 10), 4) + data % 10
end

function clock.init()
    if not RTC.enable then
        return
    end

    -- 初始化iic接口
    i2c.setup(RTC.i2c, i2c.FAST)

    -- 初始化指令
    if RTC.init ~= nil and #RTC.init > 0 then
        i2c.send(RTC.i2c, RTC.addr, RTC.init)
    end

    -- 读取RTC芯片时钟
    sys.timerStart(read, 500)
end

function clock.read()
    if not RTC.enable then
        return false
    end

    -- 发送
    local ret = i2c.send(RTC.i2c, RTC.addr, RTC.registers[1]) -- 从秒开始读
    if ret == false then
        return ret
    end

    -- 读取
    local data = i2c.recv(RTC.i2c, RTC.addr, 7)

    -- 解析
    local time = {}
    for i, v in ipairs(RTC.registers) do
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
    if not RTC.enable then
        return false
    end

    -- local tm = socket.ntptm()
    local tm = os.date("*t")

    local data = { RTC.registers[1] }
    for i, v in ipairs(RTC.registers) do
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
    local ret = i2c.send(RTC.i2c, RTC.addr, data)
    log.info(tag, "write time", ret, json.encode(tm))

    return ret
end

return clock
