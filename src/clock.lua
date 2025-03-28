--- 时钟相关
--- @module "clock"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "clock"
local clock = {}

local function bcd_to_hex(data)
    return bit.rshift(data, 4) * 10 + bit.band(data, 0x0f)
end

local function hex_to_bcd(data)
    return bit.lshift(math.floor(data / 10), 4) + data % 10
end


local default_options = {
    enable = false,
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

local options = {}

--- rtc时钟芯片初始化
function clock.init(opts)
    log.info(tag, "init")
    
    -- 加载配置
    options = opts or default_options

    if not options.enable then
        return
    end

    log.info(tag, "init")

    -- 兼容配置文件
    if type(options.init) == "string" then
        options.init = string.fromHex(options.init)
    end
    if type(options.read) == "string" then
        options.read = string.fromHex(options.read)
    end
    if type(options.write) == "string" then
        options.write = string.fromHex(options.write)
    end

    -- 初始化iic接口
    i2c.setup(options.i2c, i2c.FAST)

    -- 初始化指令
    if options.init ~= nil and #options.init > 0 then
        i2c.send(options.i2c, options.addr, options.init)
    end

    -- 读取config芯片时钟
    sys.timerStart(clock.read, 500)
end


--- 读取芯片时钟
--- @return boolean 成功与否
--- @return table {year,mon,day,wday,hour,min,sec}
function clock.read()
    if not options.enable then
        return false
    end

    -- 发送
    local ret = i2c.send(options.i2c, options.addr, options.registers[1]) -- 从秒开始读
    if ret == false then
        return ret
    end

    -- 读取
    local data = i2c.recv(options.i2c, options.addr, 7)

    -- 解析
    local time = {}
    for i, v in ipairs(options.registers) do
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

--- 写入芯片时钟
--- @return boolean 成功与否
function clock.write()
    if not options.enable then
        return false
    end

    -- local tm = socket.ntptm()
    local tm = os.date("*t")

    local data = { options.registers[1] }
    for i, v in ipairs(options.registers) do
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
    local ret = i2c.send(options.i2c, options.addr, data)
    log.info(tag, "write time", ret, json.encode(tm))

    return ret
end

return clock
