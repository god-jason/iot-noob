--- CJT188协议实现
-- @module cjt188
local cjt188 = {}

local log = iot.logger("cjt188")

local Request = require("request")

local devices = require("devices")
local protocols = require("protocols")
local binary = require("binary")
local points = require("points")
local model = require("model")
local utils = require("utils")
local meter = require("meter")

-- 单位转换代码
local units = {
    [0x01] = "J",
    [0x02] = "Wh",
    [0x03] = "Whx10",
    [0x04] = "Whx100",
    [0x05] = "kWh",
    [0x06] = "kWhx10",
    [0x07] = "kWhx100",
    [0x08] = "MWh",
    [0x09] = "MWhx10",
    [0x0A] = "MWhx100",
    [0x0B] = "kJ",
    [0x0C] = "kJx10",
    [0x0D] = "kJx100",
    [0x0E] = "MJ",
    [0x0F] = "MJx10",
    [0x10] = "MJx100",
    [0x11] = "GJ",
    [0x12] = "GJx10",
    [0x13] = "GJx100",
    [0x14] = "W",
    [0x15] = "Wx10",
    [0x16] = "Wx100",
    [0x17] = "kW",
    [0x18] = "kWx10",
    [0x19] = "kWx100",
    [0x1A] = "MW",
    [0x1B] = "MWx10",
    [0x1C] = "MWx100",
    [0x29] = "L",
    [0x2A] = "Lx10",
    [0x2B] = "Lx100",
    [0x2C] = "m3",
    [0x2D] = "m3x10",
    [0x2E] = "m3x100",
    [0x32] = "L/h",
    [0x33] = "L/hx10",
    [0x34] = "L/hx100",
    [0x35] = "m3/h",
    [0x36] = "m3/hx10",
    [0x37] = "m3/hx100",
    [0x40] = "J/h",
    [0x43] = "kj/h",
    [0x44] = "kj/hx10",
    [0x45] = "kj/hx100",
    [0x46] = "MJ/h",
    [0x47] = "MJ/hx10",
    [0x48] = "MJ/hx100",
    [0x49] = "GJ/h",
    [0x4A] = "GJ/hx10",
    [0x4B] = "GJ/hx100"
}

local function unit_convert(unit, value)
    if unit == 0x01 then
        return value * 0.001
    end
    -- 统一为kWh
    if 0x02 <= unit and unit <= 0x0A then
        return value * math.pow(10, unit - 5)
    end
    -- 统一为kJ
    if 0x0B <= unit and unit <= 0x13 then
        return value * math.pow(10, unit - 0xB)
    end
    -- 统一为kW
    if 0x14 <= unit and unit <= 0x1C then
        return value * math.pow(10, unit - 0x17)
    end
    -- 统一为m3
    if 0x29 <= unit and unit <= 0x2E then
        return value * math.pow(10, unit - 0x2C)
    end
    -- 统一为m3/h
    if 0x32 <= unit and unit <= 0x37 then
        return value * math.pow(10, unit - 0x35)
    end
    -- 统一为kJ/h
    if 0x40 <= unit and unit <= 0x4B then
        return value * math.pow(10, unit - 0x43)
    end
    return value
end

--- CJT188设备
-- @module cjt188_device
local Cjt188Device = utils.class(require("device"))
cjt188.Cjt188Device = Cjt188Device

---打开设备
function Cjt188Device:open()
    log.info("device open", self.id, self.product_id)
    self.model = model.get(self.product_id)

    -- 变化阈值
    if self.model then
        for _, prop in ipairs(self.model.content or {}) do
            for _, pt in ipairs(prop.points) do
                if pt.threshold and pt.threshold > 0 and pt.name and #pt.name > 0 then
                    self:set_threshold(pt.name, pt.threshold)
                end
            end
        end
    end
end

---读取数据
-- @param key string 点位
-- @return boolean 成功与否
-- @return any
function Cjt188Device:get(key)
    log.info("get", key)
    -- 读一遍
    self:poll()
    if self._values[key] then
        return true, self._values[key].value
    end

    return false, "找不到点位" .. key
end

---写入数据
-- @param key string 点位
-- @param value any 值
-- @return boolean 成功与否
function Cjt188Device:set(key, value)
    log.info("set", key, value)

    self._values[key] = {
        value = value,
        timestamp = os.time()
    }

    -- 找到点位，写入数据
    for _, pt in ipairs(self.model.content) do
        if pt.writable then
            for _, point in ipairs(pt.points) do
                if point.name == key then

                    -- 枚举
                    _, value = points.findEnumIndex(point, value)

                    -- 转换数据格式
                    if type(value) == "boolean" then
                        if value then
                            value = string.char(1)
                        else
                            value = string.char(0)
                        end
                    end
                    if type(value) == "number" then
                        value = string.char(value)
                    end

                    local addr = pt.company .. self.address
                    -- 逆序表示的地址（阀门）
                    if pt.address_reverse then
                        addr = binary.encodeHex(binary.reverse(binary.decodeHex(pt.company)))
                        addr = addr .. binary.encodeHex(binary.reverse(binary.decodeHex(self.address)))
                    end

                    return self.master:write(addr, pt.type, pt.code, pt.di, value)
                end
            end
        end
    end

    return false, "找不到可写点位" .. key
end

---读取所有数据
-- @return boolean 成功与否
-- @return table|nil 值
function Cjt188Device:poll()
    log.info("poll", self.id)
    if not self.model then
        return false, "没有物模型" .. self.product_id
    end
    if not self.model.content then
        return false, "没有属性表" .. self.product_id
    end

    local has = false
    local values = {}

    for _, pt in pairs(self.model.content) do
        if not pt.writable then

            log.info("poll", pt.name, pt.type, pt.code, pt.di)

            local addr = pt.company .. self.address

            -- 逆序表示的地址（阀门）
            if pt.address_reverse then
                addr = binary.encodeHex(binary.reverse(binary.decodeHex(pt.company)))
                addr = addr .. binary.encodeHex(binary.reverse(binary.decodeHex(self.address)))
            end

            -- 读数据
            local ret, data = self.master:read(addr, pt.type or "20", pt.code or "01", pt.di)
            log.info("poll read", ret, data)
            if ret then
                log.info("poll parse", binary.encodeHex(data))

                for _, point in ipairs(pt.points) do

                    if #data > point.address then
                        local ret, value, size = meter.decode(data:sub(point.address + 1), point.type, point.reverse)
                        if not ret then
                            log.error("解析数据失败", point.name, value)
                        else
                            -- 仅BCD格式有单位
                            if point.hasUnit then
                                local unit = data:byte(point.address + size + 1)
                                -- log.info("data unit", point.name, value, units[unit])
                                value = unit_convert(unit, value)
                            end

                            if point.rate and point.rate ~= 0 and point.rate ~= 1 then
                                value = value * point.rate
                            end

                            log.info("解析到数据", point.name, point.label, value)

                            -- 取位，布尔型
                            if point.bits ~= nil and #point.bits > 0 then
                                for _, b in ipairs(point.bits) do
                                    local vv = (0x01 << b.bit) & value > 0
                                    -- 取反
                                    if b["not"] then
                                        value = not value
                                    end
                                    -- self:put_value(point.name, vv)
                                    values[point.name] = vv
                                end
                            else
                                _, value = points.findEnumValue(point, value) -- 枚举
                                -- self:put_value(point.name, value)
                                values[point.name] = value
                            end

                            has = true
                        end
                    end
                end

                -- 即使没数据，至少说明读取成功了，设备还在线
                self._updated = os.time()
            end
        end
    end

    -- 存入设备
    if has then
        self:put_values(values)
        return true, values
    end

    return false, "没有读取到数据"
end

---Cjt188主站
-- @module cjt188_master
local Cjt188Master = utils.class()
cjt188.Cjt188Master = Cjt188Master

protocols.register("cjt188", Cjt188Master)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Cjt188Master
function Cjt188Master:init()
    self.link = self.link
    self.devices = self.devices or {}
    self.timeout = self.timeout or 1000
    self.request = Request:new(self.link, self.timeout)
    self.polling_interval = self.polling_interval or 1800 -- 默认半小时轮询一次
    self.increment = 0
end

-- 写入数据
-- @param addr string 地址
-- @param type integer 仪表类型
-- @param code string 指令码
-- @param di string 数据标识
-- @param data string|nil 数据
-- @return boolean 成功与否
-- @return string 只有数据
function Cjt188Master:ask(addr, type, code, di, data)
    log.info("ask", addr, type, code, di, data)

    local dl = 3
    if data and #data > 0 then
        dl = dl + #data
    end

    local frame = string.char(0x68) .. binary.decodeHex(type or "20") -- 起始符，仪表类型
    frame = frame .. binary.reverse(binary.decodeHex(addr)) -- 地址 A0- A6
    frame = frame .. binary.decodeHex(code or "01") .. string.char(dl) -- 控制符，长度
    frame = frame .. binary.reverse(binary.decodeHex(di)) -- 数据标识, 2字节
    frame = frame .. iot.pack("b1", self.increment) -- 序号
    self.increment = (self.increment + 1) % 256
    if data and #data > 0 then
        frame = frame .. data
    end
    frame = frame .. iot.pack("b1", crypto.checksum(frame, 1)) -- 和校验
    frame = frame .. iot.pack("b1", 0x16) -- 结束符

    log.info("写入", binary.encodeHex(frame))

    frame = binary.decodeHex("FEFEFEFE") .. frame -- 前导码
    local ret, buf = self.request:request(frame, 14) -- 先读12字节
    if not ret then
        return false, buf or "无响应"
    end

    log.info("读取", binary.encodeHex(buf))

    -- 解析返回
    -- 去掉前导码
    while #buf > 0 and string.byte(buf, 1) == 0xFE do
        buf = buf:sub(2)
    end

    if string.byte(buf, 1) ~= 0x68 then
        return false, "错误起始"
    end

    -- 指令长度不够，要拿到长度
    if #buf < 12 then
        local ret2, buf2 = self.request:request(nil, 12 - #buf) -- 继续读
        if ret2 then
            buf = buf .. buf2
        else
            return false, "读取更多失败 " .. buf2
        end
    end

    -- 数据长度不足，则继续读
    local len = string.byte(buf, 11) -- 数据段长度
    if #buf < len + 12 then
        local ret2, buf2 = self.request:request(nil, len + 12 - #buf) -- 继续读
        if ret2 then
            buf = buf .. buf2
        else
            return false, "读取全部失败 " .. buf2
        end
    end

    return true, buf:sub(15, -3) -- 去掉包头，长度，数据标识，序号，校验和结束符
end

--- 读取数据
-- @param addr string 地址
-- @param type integer 仪表类型
-- @param code string 指令码
-- @param di string 数据标识
-- @return boolean 成功与否
-- @return string 只有数据
function Cjt188Master:read(addr, type, code, di)
    log.info("read", addr, type, code, di)
    -- self.link:read() -- 清空接收区数据
    return self:ask(addr, type, code, di, nil)
end

-- 写入数据
-- @param addr string 地址
-- @param type integer 仪表类型
-- @param code string 指令码
-- @param di string 数据标识
-- @param data string 数据
-- @return boolean 成功与否
-- @return string 只有数据
function Cjt188Master:write(addr, type, code, di, data)
    log.info("write", addr, type, code, di, data)
    -- self.link:read() -- 清空接收区数据
    return self:ask(addr, type, code, di, data)
end

---打开主站
function Cjt188Master:open()
    if self.opened then
        return false, "已经打开了"
    end
    self.opened = true

    -- 启动设备
    for _, d in ipairs(self.devices) do
        log.info("open device", iot.json_encode(d))
        local dev = Cjt188Device:new(d)
        dev.master = self
        dev:open()

        devices.register(d.id, dev)
    end

    -- 开启轮询
    if self.polling ~= false then
        iot.start(Cjt188Master._polling, self)
    end

    return true
end

--- 关闭
function Cjt188Master:close()
    self.opened = false
    self.devices = {}
end

--- 轮询
function Cjt188Master:_polling()
    log.info("polling thread start")

    -- 轮询间隔
    local interval = self.polling_interval or 1800
    interval = interval * 1000 -- 毫秒

    log.info("polling interval", interval)

    while self.opened do
        log.info("polling start")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        for _, dev in pairs(self.devices) do
            iot.xcall(dev.poll, dev)

            -- 等待数据完成
            iot.sleep(500)
        end

        local finish = mcu.ticks()
        local remain = interval - (finish - start)
        if remain > 0 then
            iot.sleep(remain)
        end
    end
end

return cjt188
