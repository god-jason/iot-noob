--- 组件 时钟芯片 PCF8563
-- @module RTC
local RTC = {}
RTC.__index = RTC

require("components").register("rtc", RTC)

local log = iot.logger("rtc")

local function bcd2dec(v)
    return (v >> 4) * 10 + (v & 0x0F)
end

local function dec2bcd(v)
    return ((v // 10) << 4) | (v % 10)
end

--- 初始化
function RTC:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        i2c = opts.i2c or 1,
        addr = opts.addr or 0x51,
        reg = opts.reg or 0x02
    }, RTC)
    return obj
end

function RTC:open()
    local ret, iic = iot.i2c(self.i2c, {
        fast = true
    })
    if not ret then
        log.error("打开IIC失败")
        return false, iic
    end
    self.iic = iic

    -- 测试代码，延迟1s读取
    -- iot.setTimeout(RTC.read, 1000, self)

    return true
end

function RTC:close()
    if self.iic then
        self.iic:close()
        self.iic = nil
    end
end

--- 读时钟
function RTC:read()

    -- 自动打开
    if not self.iic then
        local ret, iic = iot.i2c(self.i2c)
        if not ret then
            return ret, iic
        end
        self.iic = iic
    end

    -- 读取寄存器
    local ret, data = self.iic:readRegister(self.addr, self.reg, 7)
    if not ret then
        return false, "读取RTC失败"
    end
    if #data < 7 then
        return false, "读取RTC数据错误"
    end

    -- 转换
    local tm = {
        sec = bcd2dec(data:byte(1) & 0x7F),
        min = bcd2dec(data:byte(2) & 0x7F),
        hour = bcd2dec(data:byte(3) & 0x3F),
        day = bcd2dec(data:byte(4) & 0x3F),
        wday = bcd2dec(data:byte(5) & 0x07) + 1,
        mon = bcd2dec(data:byte(6) & 0x9F),
        year = bcd2dec(data:byte(7)) + 2000
    }

    -- 写入系统时钟
    rtc.set(tm)

    log.info("时钟芯片读值", iot.json_encode(tm))

    -- 发布消息
    iot.emit("RTC_OK", tm)

    if self.on_change then
        pcall(self.on_change, "time", os.date("%Y-%m-%d %H:%M:%S", os.time(tm))) -- 转为日期串
    end

    return true, tm
end

--- 写时钟
-- @param tm table
function RTC:write(tm)

    -- 自动打开
    if not self.iic then
        local ret, iic = iot.i2c(self.i2c)
        if not ret then
            return ret, iic
        end
        self.iic = iic
    end

    -- 默认取系统时间
    local t = tm or os.date("*t")
    local data = string.char(dec2bcd(t.sec), dec2bcd(t.min), dec2bcd(t.hour), dec2bcd(t.day),
        dec2bcd((t.wday or 1) - 1), dec2bcd(t.month), dec2bcd(t.year % 100))

    -- 写入寄存器
    local ret = self.iic:writeRegister(self.addr, self.reg, data)
    if ret then
        log.info("时钟芯片写值", iot.json_encode(t))
        return false, "写入RTC失败"
    end

    return true
end

return RTC
