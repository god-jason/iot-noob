--- 时钟相关
-- @module driver_clock
local clock = {}

local tag = "clock"

local function bcd_to_hex(data)
    return bit.rshift(data, 4) * 10 + bit.band(data, 0x0f)
end

local function hex_to_bcd(data)
    return bit.lshift(data // 10, 4) + data % 10
end

local configs = require("configs")

local default_options = {
    enable = false,
    chip = "SD3077", -- 型号
    i2c = 1, -- iic总线
    addr = 0x32, -- 地址 0x64: SD3077, 0x68 SD3231
    reg = 0x00, -- 首地址
    fields = { -- 寄存器
    "second", "minute", "hour", "wday", "day", "month", "year"}

}

local options = {}

--- rtc时钟芯片初始化
function clock.init()
    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    log.info(tag, "init")

    -- 初始化iic接口
    i2c.setup(options.i2c, i2c.SLOW)

    -- 读取config芯片时钟
    iot.setTimeout(clock.read, 500)
end

--- 读取芯片时钟
-- @return boolean 成功与否
-- @return table {year,mon,day,wday,hour,min,sec}
function clock.read()
    if not options.enable then
        return false
    end

    -- 读取
    local data = i2c.readReg(options.i2c, options.addr, options.reg, 7)
    if not data or #data ~= 7 then
        return false
    end

    -- 解析
    local time = {}
    for i, v in ipairs(options.fields) do
        if v == "year" then
            time.year = bcd_to_hex(data:byte(i)) + 2000
        elseif v == "month" then
            time.mon = bcd_to_hex(bit.band(data:byte(i), 0x7f)) - 1
        elseif v == "day" then
            time.day = bcd_to_hex(data:byte(i))
        elseif v == "wday" then
            time.wday = bcd_to_hex(data:byte(i)) + 1
        elseif v == "hour" then
            time.hour = bcd_to_hex(bit.band(data:byte(i), 0x7f)) -- 最高位代表 24小时制
        elseif v == "minute" then
            time.min = bcd_to_hex(data:byte(i))
        elseif v == "second" then
            time.sec = bcd_to_hex(data:byte(i))
        end
    end
    log.info(tag, "read time", json.encode(time))

    -- 设置到系统中
    local r = rtc.set(time)
    log.info(tag, "set time", r, json.encode(time))

    return true, time
end

--- 写入芯片时钟
-- @return boolean 成功与否
function clock.write()
    if not options.enable then
        return false
    end

    -- local tm = socket.ntptm()
    local tm = os.date("*t")

    local data = {}
    for _, v in ipairs(options.fields) do
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
    local ret = i2c.writeReg(options.i2c, options.addr, options.reg, data)
    log.info(tag, "write time", ret, json.encode(tm))

    return ret
end

-- 启动
clock.init()

local sntp_sync_ok = false

sys.subscribe("IP_READY", function()
    -- 同步时钟（联通卡不会自动同步时钟，所以必须手动调整）
    if not sntp_sync_ok then
        socket.sntp()
        -- socket.sntp("ntp.aliyun.com") --自定义sntp服务器地址
        -- socket.sntp({"ntp.aliyun.com","ntp1.aliyun.com","ntp2.aliyun.com"}) --sntp自定义服务器地址
        -- socket.sntp(nil, socket.ETH0) --sntp自定义适配器序号
    end
end)

sys.subscribe("NTP_UPDATE", function()
    sntp_sync_ok = true
    -- 设置到RTC时钟芯片
    clock.write()
end)

return clock
