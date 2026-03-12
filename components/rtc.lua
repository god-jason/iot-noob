--- 组件 时钟芯片
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
    
    -- 默认打开
    obj:open()

    return obj
end

function RTC:open()
    local ret, iic = iot.i2c(self.i2c)
    if not ret then
        log.error("打开IIC失败")
        return false, iic
    end
    self.iic = iic
    
    -- 测试代码，延迟1s读取
    iot.setTimeout(RTC.read, 1000, self)

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
    if not self.iic then
        return false, "i2c未打开"
    end

    self.iic:write(self.addr, {self.reg})
    local ret, data = self.iic:read(self.addr, 7)
    if not ret then
        return false, "读取RTC失败"
    end

    local tm = {
        sec = bcd2dec(data:byte(1)),
        min = bcd2dec(data:byte(2)),
        hour = bcd2dec(data:byte(3)),
        wday = bcd2dec(data:byte(4)),
        day = bcd2dec(data:byte(5)),
        mon = bcd2dec(data:byte(6)),
        year = 2000 + bcd2dec(data:byte(7))
    }

    -- 写入系统时钟
    rtc.set(tm)

    log.info("时钟芯片读值", iot.json_encode(tm))

    -- 发布消息
    iot.emit("RTC_OK", tm)

    return true, tm
end

--- 写时钟
-- @param tm table
function RTC:write(tm)
    if not self.iic then
        return false, "i2c未打开"
    end

    local t = tm or os.date("t*") -- 默认取系统时间
    local data = {self.reg, dec2bcd(t.sec), dec2bcd(t.min), dec2bcd(t.hour), dec2bcd(t.wday or 1), dec2bcd(t.day),
                  dec2bcd(t.mon), dec2bcd(t.year % 100)}
    return self.iic:write(self.addr, data)
end

return RTC
