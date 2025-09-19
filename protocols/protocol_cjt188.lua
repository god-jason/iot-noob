--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- CJT188协议实现
-- @module protocol_cjt188
local Cjt188Device = {}

local tag = "cjt188"

local Agent = require("agent")
local Device = require("device")

local database = require("database")
local gateway = require("gateway")
local binary = require("binary")

local mapper_cache = {}
local function load_mapper(product_id)
    if mapper_cache[product_id] then
        return mapper_cache[product_id]
    end

    local model = database.get("model", product_id)
    if not model then
        return nil
    end

    -- 按数据标识分组
    -- di->points[]
    local mapper = {}
    for _, p in ipairs(model.properties or {}) do
        for _, pt in ipairs(p.points) do
            local points = mapper[pt.di]
            if not points then
                points = {}
                mapper[pt.di] = points
            end
            table.insert(points, pt)
        end
    end
end

-- 单位转换代码
-- local units = {
--     [0x01] = "J",
--     [0x02] = "Wh",
--     [0x03] = "Whx10",
--     [0x04] = "Whx100",
--     [0x05] = "kWh",
--     [0x06] = "kWhx10",
--     [0x07] = "kWhx100",
--     [0x08] = "MWh",
--     [0x09] = "MWhx10",
--     [0x0A] = "MWhx100",
--     [0x0B] = "kJ",
--     [0x0C] = "kJx10",
--     [0x0D] = "kJx100",
--     [0x0E] = "MJ",
--     [0x0F] = "MJx10",
--     [0x10] = "MJx100",
--     [0x11] = "GJ",
--     [0x12] = "GJx10",
--     [0x13] = "GJx100",
--     [0x14] = "W",
--     [0x15] = "Wx10",
--     [0x16] = "Wx100",
--     [0x17] = "kW",
--     [0x18] = "kWx10",
--     [0x19] = "kWx100",
--     [0x1A] = "MW",
--     [0x1B] = "MWx10",
--     [0x1C] = "MWx100",    
--     [0x29] = "L",
--     [0x2A] = "Lx10",
--     [0x2B] = "Lx100",
--     [0x2C] = "m3",
--     [0x2D] = "m3x10",
--     [0x2E] = "m3x100",
--     [0x32] = "L/h",
--     [0x33] = "L/hx10",
--     [0x34] = "L/hx100",
--     [0x35] = "m3/h",
--     [0x36] = "m3/hx10",
--     [0x37] = "m3/hx100",
--     [0x40] = "J/h",
--     [0x43] = "kj/h",
--     [0x44] = "kj/hx10",
--     [0x45] = "kj/hx100",
--     [0x46] = "MJ/h",
--     [0x47] = "MJ/hx10",
--     [0x48] = "MJ/hx100",
--     [0x49] = "GJ/h",
--     [0x4A] = "GJ/hx10",
--     [0x4B] = "GJ/hx100",
-- }

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
    ["YYYYMMDD"] = {
        type = "date",
        size = 4
    }
}

---创建设备
-- @param dev table 设备参数
-- @param master Cjt188Master 主站实例
-- @return Cjt188Device 实例
function Cjt188Device:new(dev, master)
    local dev = setmetatable(Device:new(obj), self) -- 继承Device
    dev.master = master
    return dev
end

---打开设备
function Cjt188Device:open()
    log.info(tag, "device open", self.id, self.product_id)
    self.mapper = load_mapper(self.product_id)
end

---读取数据
-- @param key string 点位
-- @return boolean 成功与否
-- @return any
function Cjt188Device:get(key)
    log.info(tag, "get", key)
    -- 读一遍
    self:poll()
    if self.values[key] then
        return true, self.values[key].value
    end
end

---写入数据
-- @param key string 点位
-- @param value any 值
-- @return boolean 成功与否
function Cjt188Device:set(key, value)
    log.info(tag, "set", key, value)
    self.master.read(0, 0, 0, 0)
end

---读取所有数据
-- @return boolean 成功与否
-- @return table|nil 值
function Cjt188Device:poll()
    log.info(tag, "poll", self.id)
    if not self.mapper then
        log.error(tag, "poll", self.id, "no mapper")
        return false, "no mapper"
    end

    for di, points in pairs(self.mapper) do
        -- 读数据
        local ret, data = self.master.read(self.address, di)
        if ret then
            for _, point in ipairs(points) do
                local fmt = types[point.type]
                if fmt then
                    local value
                    if fmt.type == "bcd" then
                        value = binary.decodeBCD(fmt.size, data:sub(point.address + 1, point.address + fmt.size))
                        if point.unit then
                            value = unit_convert(point.unit, value)
                        end
                        if fmt.rate then
                            value = value * fmt.rate
                        end
                        self:put_value(point.key, value)
                    elseif fmt.type == "hex" then
                        value = 0
                        for i = 1, fmt.size do
                            value = (value << 8) | data:byte(i)
                        end
                        -- 取位，布尔型
                        if point.bit > 0 then
                            value = (value >> (point.bit - 1)) & 0x01
                        end
                        self:put_value(point.key, value)
                    elseif fmt.type == "datetime" then
                        value = binary.encodeHex(data:sub(1, fmt.size)) -- 字符串 YYYYMMDDhhmmss
                        self:put_value(point.key, value)
                    elseif fmt.type == "date" then
                        value = binary.encodeHex(data:sub(1, fmt.size)) -- 字符串 YYYYMMDD
                        self:put_value(point.key, value)
                    else
                        log.error(tag, "poll", self.id, "unknown format type", fmt.type)
                    end

                else
                    log.error(tag, "poll", self.id, "unknown format", point.type)
                end
            end
        end
    end

end

local Cjt188Master = {}
Cjt188Master.__index = Cjt188Master

require("protocols").register("cjt188", Cjt188Master)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Cjt188Master
function Cjt188Master:new(link, opts)
    local master = setmetatable({}, self)
    self.__index = Agent:new(link)
    master.link = link
    master.timeout = opts.timeout or 1000 -- 1秒钟
    master.poller_interval = opts.poller_interval or 5 -- 5秒钟
    master.increment = 1

    return master
end

--- 读取数据
-- @param addr string 地址
-- @param type integer 仪表类型
-- @param di string 数据标识
-- @return boolean 成功与否
-- @return string 只有数据
function Cjt188Master:read(addr, type, di)
    log.info(tag, "read", addr, di)
    self.link.ask("abc", 7)

    local data = pack.pack("b2", 0x68, type) -- 起始符，仪表类型
    data = data .. binary.reverse(binary.decodeHex(addr)) -- 地址 A0- A6
    data = data .. pack.pack("b2", 0x01, 3) -- 控制符，长度
    data = data .. binary.reverse(binary.decodeHex(di)) -- 数据标识, 2字节
    data = data .. pack.pack("b1", self.increment) -- 序号
    self.increment = (self.increment + 1) % 256
    data = data .. crypto.checksum(data, 1) -- 和校验
    data = data .. pack.pack("b1", 0x16) -- 结束符

    local frame = binary.decodeHex("FEFEFEFE") .. data -- 前导码
    local ret, buf = self.link:ask(frame, self.timeout)
    if not ret then
        return false, "no response"
    end

    -- 解析返回
    -- 去掉前导码
    while #buf > 0 and string.byte(buf, 1) == 0xFE do
        buf = buf:sub(2)
    end

    if #buf < 12 then
        local ret2, buf2 = self.link:read() -- 继续读
        if ret2 then
            buf = buf .. buf2
        else
            return false, "invalid response"
        end
    end

    if string.byte(buf, 1) ~= 0x68 then
        return false, "invalid start"
    end

    return true, buf.sub(15, -3) -- 去掉包头，长度，数据标识，序号，校验和结束符
end

-- 写入数据
-- @param slave integer 从站号
-- @param code integer 功能码
-- @param addr integer 地址
-- @param data string 数据
-- @return boolean 成功与否
function Cjt188Master:write(slave, code, addr, data)
    log.info(tag, "write", slave, code, addr, data)
    self.link.ask("abc", 7)
end

---打开主站
function Cjt188Master:open()
    log.info(tag, "open")
    local dev = Cjt188Device:new()
    log.info(tag, dev)
    table.insert(self.devices, dev) -- 先随便写，不测试

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

    while self.opened do
        log.info(tag, "polling start")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        for _, dev in pairs(self.devices) do

            -- 加入异常处理（pcall不能调用对象实例，只是用闭包了）
            local ret, info = pcall(function()

                local ret, values = dev:poll()
                if ret then
                    log.info(tag, "polling", dev.id, "succeed")
                    -- log.info(tag, "polling", dev.id, "values", json.encode(values))
                    -- 向平台发布消息
                    -- cloud.publish("device/" .. dev.product_id .. "/" .. dev.id .. "/property", values)
                    sys.publish("DEVICE_VALUES", dev, values)
                else
                    log.error(tag, "polling", dev.id, "failed")
                end

            end)
            if not ret then
                log.error(tag, "polling", dev.id, "error", info)
            end

        end

        local finish = mcu.ticks()
        local remain = interval - (finish - start)
        if remain > 0 then
            sys.wait(remain)
        end
    end
end

