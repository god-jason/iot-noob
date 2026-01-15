--- CJT188协议实现
-- @module cjt188_device
local Cjt188Device = {}
Cjt188Device.__index = Cjt188Device

local tag = "cjt188"

local Agent = require("agent")
local Device = require("device")
-- setmetatable(Cjt188Device, {__index = Device}) -- 继承Device
setmetatable(Cjt188Device, Device) -- 继承Device

local database = require("database")
local gateway = require("gateway")
local binary = require("binary")
local points = require("points")

local model_cache = {}
local function load_model(product_id)
    if model_cache[product_id] then
        return model_cache[product_id]
    end

    log.info(tag, "load model", product_id)

    local model = database.get("model", product_id)
    if not model then
        return nil
    end

    model_cache[product_id] = model
    return model
end

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

-- 数据格式
local types = {
    ["XXXXXXXX"] = {
        type = "bcd",
        size = 4
    },
    ["XXXXXX.XX"] = {
        type = "bcd",
        size = 4,
        rate = 0.01
    },
    ["XXXX.XXXX"] = {
        type = "bcd",
        size = 4,
        rate = 0.0001
    },
    ["XXXXXX"] = {
        type = "bcd",
        size = 3
    },
    ["XXXX.XX"] = {
        type = "bcd",
        size = 3,
        rate = 0.01
    },
    ["XXXX"] = {
        type = "bcd",
        size = 2
    },
    ["XX.XX"] = {
        type = "bcd",
        size = 2,
        rate = 0.01
    },
    ["XX"] = {
        type = "bcd",
        size = 1
    },
    ["HH"] = {
        type = "hex",
        size = 1
    },
    ["HHHH"] = {
        type = "hex",
        size = 2
    },
    ["YYYYMMDDhhmmss"] = {
        type = "datetime",
        size = 7
    },
    ["YYMMDDhhmmss"] = {
        type = "datetime6",
        size = 6
    },
    ["YYMMDDhhmm"] = {
        type = "datetime5",
        size = 5
    },
    ["YYYYMMDD"] = {
        type = "date",
        size = 4
    },
    ["uint8"] = {
        type = "u8",
        size = 1
    },
    ["uint16"] = {
        type = "u16",
        size = 2
    }

}

---创建设备
-- @param obj table 设备参数
-- @param master Cjt188Master 主站实例
-- @return Cjt188Device 实例
function Cjt188Device:new(obj, master)
    local dev = setmetatable(Device:new(obj), self) -- 继承Device
    dev.master = master
    return dev
end

---打开设备
function Cjt188Device:open()
    log.info(tag, "device open", self.id, self.product_id)
    self.model = load_model(self.product_id)
end

---读取数据
-- @param key string 点位
-- @return boolean 成功与否
-- @return any
function Cjt188Device:get(key)
    log.info(tag, "get", key)
    -- 读一遍
    self:poll()
    if self._values[key] then
        return true, self._values[key].value
    end
end

---写入数据
-- @param key string 点位
-- @param value any 值
-- @return boolean 成功与否
function Cjt188Device:set(key, value)
    log.info(tag, "set", key, value)

    self._values[key] = {
        value = value,
        timestamp = os.time()
    }

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

    -- 找到点位，写入数据
    for _, pt in ipairs(self.model.properties) do
        if pt.writable then
            for _, point in ipairs(pt.points) do
                if point.name == key then

                    -- 枚举
                    _, value = points.findEnumIndex(point, value)

                    local addr = pt.company .. self.address
                    -- 逆序表示的地址（阀门）
                    if pt.address_reverse then
                        addr = binary.encodeHex(binary.reverse(binary.decodeHex(pt.company)))
                        addr = addr .. binary.encodeHex(binary.reverse(binary.decodeHex(self.address)))
                    end

                    self.master:write(addr, pt.type, pt.code, pt.di, value)
                end
            end
        end
    end
end

---读取所有数据
-- @return boolean 成功与否
-- @return table|nil 值
function Cjt188Device:poll()
    log.info(tag, "poll", self.id)
    if not self.model then
        log.error(tag, "poll", self.id, "no model")
        return false, "no model"
    end
    if not self.model.properties then
        log.error(tag, "poll", self.id, "no properties")
        return false, "no properties"
    end

    for _, pt in pairs(self.model.properties) do
        if not pt.writable then

            log.info(tag, "poll", pt.name, pt.type, pt.code, pt.di)

            local addr = pt.company .. self.address

            -- 逆序表示的地址（阀门）
            if pt.address_reverse then
                addr = binary.encodeHex(binary.reverse(binary.decodeHex(pt.company)))
                addr = addr .. binary.encodeHex(binary.reverse(binary.decodeHex(self.address)))
            end

            -- 读数据
            local ret, data = self.master:read(addr, pt.type or "20", pt.code or "01", pt.di)
            log.info(tag, "poll read", ret, data)
            if ret then
                log.info(tag, "poll parse", binary.encodeHex(data))

                for _, point in ipairs(pt.points) do
                    local fmt = types[point.type]
                    if fmt then
                        if #data > point.address then
                            local str = data:sub(point.address + 1, point.address + fmt.size)
                            log.info(tag, "poll decode", point.name, point.label, fmt.type, binary.encodeHex(str), str)

                            local value
                            if fmt.type == "bcd" then
                                str = binary.reverse(str)
                                value = binary.decodeBCD(fmt.size, str)
                                if point.hasUnit then
                                    local unit = data:byte(point.address + fmt.size + 1)
                                    log.info(tag, "data unit", point.name, value, units[unit])
                                    value = unit_convert(unit, value)
                                end
                                if fmt.rate then
                                    value = value * fmt.rate
                                end
                                self:put_value(point.name, value)
                            elseif fmt.type == "hex" then
                                value = 0
                                for i = 1, fmt.size do
                                    value = (value << 8) | str:byte(1)
                                end

                                -- 取位，布尔型
                                if point.bits ~= nil and #point.bits > 0 then
                                    for _, b in ipairs(point.bits) do
                                        local vv = (0x01 << b.bit) & value > 0
                                        -- 取反
                                        if b["not"] then
                                            value = not value
                                        end
                                        self:put_value(b.name, vv)
                                    end
                                else
                                    _, value = points.findEnumValue(point, value) -- 枚举
                                    self:put_value(point.name, value)
                                end
                            elseif fmt.type == "datetime" then
                                str = binary.reverse(str)
                                value = binary.encodeHex(str) -- 字符串 YYYYMMDDhhmmss
                                self:put_value(point.name, value)
                            elseif fmt.type == "date" then
                                str = binary.reverse(str)
                                value = binary.encodeHex(str) -- 字符串 YYYYMMDD
                                self:put_value(point.name, value)
                            elseif fmt.type == "datetime6" then
                                str = binary.reverse(str)
                                value = "20" .. binary.encodeHex(str) -- 字符串
                            elseif fmt.type == "datetime5" then
                                str = binary.reverse(str)
                                value = "20" .. binary.encodeHex(str) .. "00" -- 字符串
                            elseif fmt.type == "u8" then
                                value = str:byte(1)
                                if fmt.rate then
                                    value = value * fmt.rate
                                end
                                if point.rate then
                                    value = value * point.rate
                                end
                                _, value = points.findEnumValue(point, value) -- 枚举
                                self:put_value(point.name, value)
                            elseif fmt.type == "u16" then
                                _, value = iot.unpack(str, "<H")
                                if fmt.rate then
                                    value = value * fmt.rate
                                end
                                if point.rate then
                                    value = value * point.rate
                                end
                                _, value = points.findEnumValue(point, value) -- 枚举
                                self:put_value(point.name, value)
                            else
                                log.error(tag, "poll", self.id, "unknown format type", fmt.type)
                            end
                        else
                            log.error(tag, "poll", self.id, "data too short", #data, point.address)
                        end
                    else
                        log.error(tag, "poll", self.id, "unknown format", point.type)
                    end
                end
            end
        end

        -- 数据更新时间
        self._updated = os.time()
    end

    return true
end

---Cjt188主站
-- @module cjt188_master
local Cjt188Master = {}
Cjt188Master.__index = Cjt188Master

gateway.register_protocol("cjt188", Cjt188Master)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Cjt188Master
function Cjt188Master:new(link, opts)
    local master = setmetatable({}, self)
    master.link = link
    master.timeout = opts.timeout or 2000
    master.agent = Agent:new(link, master.timeout)
    master.poller_interval = opts.poller_interval or 10
    master.increment = 0

    return master
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

    log.info(tag, "frame", binary.encodeHex(frame))

    frame = binary.decodeHex("FEFEFEFE") .. frame -- 前导码
    local ret, buf = self.agent:ask(frame, 14) -- 先读12字节
    if not ret then
        return false, "no response"
    end

    log.info(tag, "response", binary.encodeHex(buf))

    -- 解析返回
    -- 去掉前导码
    while #buf > 0 and string.byte(buf, 1) == 0xFE do
        buf = buf:sub(2)
    end

    if string.byte(buf, 1) ~= 0x68 then
        return false, "invalid start"
    end

    -- 指令长度不够，要拿到长度
    if #buf < 12 then
        local ret2, buf2 = self.agent:ask(nil, 12 - #buf) -- 继续读
        if ret2 then
            buf = buf .. buf2
        else
            return false, "read more fail " .. buf2
        end
    end

    -- 数据长度不足，则继续读
    local len = string.byte(buf, 11) -- 数据段长度
    if #buf < len + 12 then
        local ret2, buf2 = self.agent:ask(nil, len + 12 - #buf) -- 继续读
        if ret2 then
            buf = buf .. buf2
        else
            return false, "read all data fail " .. buf2
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
    log.info(tag, "read", addr, type, code, di)
    self.link:read() -- 清空接收区数据
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
    log.info(tag, "write", addr, type, code, di, data)
    self.link:read() -- 清空接收区数据
    return self:ask(addr, type, code, di, data)
end

---打开主站
function Cjt188Master:open()
    if self.opened then
        log.error(tag, "already opened")
        return
    end
    self.opened = true

    -- 加载设备
    -- local ds = devices.load_by_link(self.link.id)
    local ds = database.find("device", "link_id", self.link.id)

    -- 启动设备
    self.devices = {}
    for _, d in ipairs(ds) do
        log.info(tag, "open device", iot.json_encode(d))
        local dev = Cjt188Device:new(d, self)
        dev:open()

        self.devices[d.id] = dev

        gateway.register_device_instanse(d.id, dev)
    end

    -- 开启轮询
    local this = self
    self.task = iot.start(function()
        -- 这个写法。。。
        this:_polling()
    end)
end

--- 关闭
function Cjt188Master:close()
    self.opened = false
    self.devices = {}
end

--- 轮询
function Cjt188Master:_polling()
    -- 轮询间隔
    local interval = self.poller_interval or 60
    interval = interval * 1000 -- 毫秒

    log.info(tag, "polling interval", interval)

    while self.opened do
        log.info(tag, "polling start")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        for _, dev in pairs(self.devices) do

            -- 加入异常处理（pcall不能调用对象实例，只是用闭包了）
            local ret, info = pcall(function()
                local ret, info = dev:poll()
                if not ret then
                    log.error(tag, "polling", dev.id, info)
                end
            end)
            if not ret then
                log.error(tag, "polling", dev.id, "error", info)
            end

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

