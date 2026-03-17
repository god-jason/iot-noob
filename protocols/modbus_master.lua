--- Modbus 协议实现
-- @module modbus_master_device
local ModbusMasterDevice = {}
ModbusMasterDevice.__index = ModbusMasterDevice

local log = iot.logger("modbus_master")

local Request = require("request")
local Device = require("device")
setmetatable(ModbusMasterDevice, Device) -- 继承Device

local database = require("database")
local devices = require("devices")
local protocols = require("protocols")
local points = require("points")
local model = require("model")
local utils = require("utils")
local modbus = require("modbus")

---创建设备
-- @param obj table 设备参数
-- @param master Modbus 主站实例
-- @return Device 实例
function ModbusMasterDevice:new(obj, master)
    local dev = setmetatable(Device:new(obj), self) -- 继承Device
    dev.master = master
    return dev
end

---打开设备
function ModbusMasterDevice:open()
    log.info("device open", self.id, self.product_id)
    self.mapper = modbus.load_mapper(self.product_id)

    -- TODO 优化
    self.model = model.get(self.product_id)
    -- 变化阈值
    if self.model then
        for _, prop in ipairs(self.model.properties or {}) do
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
function ModbusMasterDevice:get(key)
    log.info("get", key, self.id)
    local point = self.mapper:find(key)
    if not point then
        return false, "找不到点位" .. key
    end

    local ret = false
    local data

    if point.register == 1 or point.register == 2 then
        ret, data = self.master:read(self.slave, point.register, point.address, 1)
        if not ret then
            return false, data
        end
        -- 直接判断返回值就行了 FF00 0000
        ret, data = points.parseBit(point, data, point.address)
    elseif point.register == 3 or point.register == 4 then
        local feagure = points.feagure(point.type)
        if not feagure then
            return false, "找不到类型"
        end
        ret, data = self.master:read(self.slave, point.register, point.address, feagure.word)
        if not ret then
            return false, data
        end
        ret, data = points.parseWord(point, data, point.address)
    end

    -- 替换到缓存中
    if ret then
        self:put_value(key, data)
    end
    return ret, data
end

---写入数据
-- @param key string 点位
-- @param value any 值
-- @return boolean 成功与否
function ModbusMasterDevice:set(key, value)
    log.info("set", key, value, self.id)
    local point = self.mapper:find_write(key)
    if not point then
        return false, "找不到点位" .. key
    end

    local ret
    local data
    local code = point.register

    -- 编码数据
    if code == 1 or code == 2 then
        if value then
            data = string.fromHex("FF00")
        else
            data = string.fromHex("0000")
        end
        code = 5
    else
        ret, data = points.encode(point, value)
        if not ret then
            return false, data
        end
        code = 6
    end

    return self.master:write(self.slave, code, point.address, data)
end

---读取所有数据
function ModbusMasterDevice:poll()
    log.info("poll", self.id)
    -- log.info("poller", iot.json_encode(self.options.pollers))

    -- 没有轮询器，直接返回
    if not self.mapper.pollers or #self.mapper.pollers == 0 then
        log.info(self.id, self.product_id, "没有轮询器")
        return false, "没有轮询器"
    end

    -- 依次轮询
    for _, poller in ipairs(self.mapper.pollers) do
        local res, data = self.master:read(self.slave, poller.register, poller.address, poller.length)
        if res then
            log.info("poll read", #data)
            local ret, values = self.mapper:parse(data, poller.register, poller.address, poller.length)
            if ret then
                -- 存入数据
                self:put_values(values)
            end
        else
            log.error("轮询失败", data)
        end
    end

    return true
end

---Modbus主站
-- @module modbus_master
local ModbusMaster = {}
ModbusMaster.__index = ModbusMaster

protocols.register("modbus", ModbusMaster)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Master
function ModbusMaster:new(link, opts)
    local master = setmetatable({}, self)
    master.link = link
    master.timeout = opts.timeout or 1000 -- 1秒钟
    master.request = Request:new(link, master.timeout)
    master.poller_interval = opts.poller_interval or 5 -- 5秒钟
    master.tcp = opts.tcp or false -- modbus tcp
    master.increment = 1 -- modbus-tcp序号

    return master
end

function ModbusMaster:readTCP(slave, code, addr, len)
    log.info("readTCP", slave, code, addr, len)

    local data = iot.pack("b2>H2", slave, code, addr, len)
    -- 事务ID, 0000, 长度
    local header = iot.pack(">H3", self.increment, 0, #data)
    self.increment = self.increment + 1

    local ret, buf = self.request:request(header .. data, 12)
    if not ret then
        return false, buf
    end

    -- 取错误码
    if #buf > 8 then
        local code2 = string.byte(buf, 8)
        if code2 > 0x80 then
            log.error("错误码", code2)
            return false, "错误码" .. code2
        end
    end

    -- 解析包头
    local _, _, ln = iot.unpack(buf, ">H3")
    len = ln + 6

    -- 取剩余数据
    if #buf < len then
        log.info("等待更多", len, #buf)
        local r, d = self.request:request(nil, len - #buf)
        if not r then
            return false, d
        end
        buf = buf .. d
    end

    return true, string.sub(buf, 10)
end

-- 读取数据
-- @param slave integer 从站号
-- @param code integer 功能码
-- @param addr integer 地址
-- @param len integer 长度
-- @return boolean 成功与否
-- @return string 只有数据
function ModbusMaster:read(slave, code, addr, len)
    if self.tcp then
        return self:readTCP(slave, code, addr, len)
    end

    log.info("read", slave, code, addr, len)

    local data = iot.pack("b2>H2", slave, code, addr, len)
    local crc = iot.pack('<H', modbus.crc16(data))

    local ret, buf = self.request:request(data .. crc, 7)
    if not ret then
        return false, buf
    end

    -- 取错误码
    if #buf > 3 then
        local code2 = string.byte(buf, 2)
        if code2 > 0x80 then
            log.error("错误码", code2)
            return false, "错误码" .. code2
        end
    end

    -- 先取字节数
    local cnt = string.byte(buf, 3)
    local len2 = 5 + cnt
    if #buf < len2 then
        log.info("等待更多", len2, #buf)
        local r, d = self.request:request(nil, len2 - #buf)
        if not r then
            return false, d
        end
        buf = buf .. d
    end

    return true, string.sub(buf, 4, len2 - 2)
end

function ModbusMaster:writeTCP(slave, code, addr, data)
    log.info("writeTCP", slave, code, addr, data)

    data = iot.pack("b2>H", slave, code, addr) .. data

    -- 事务ID, 0000, 长度
    local header = iot.pack(">H3", self.increment, 0, #data)
    self.increment = self.increment + 1

    local ret, buf = self.request:request(header .. data, 12)
    if not ret then
        return false, buf
    end

    -- 取错误码
    if #buf > 8 then
        local code2 = string.byte(buf, 8)
        if code2 > 0x80 then
            log.error("错误码", code2)
            return false, "错误码" .. code2
        end
    end

    -- 解析包头
    local _, _, ln = iot.unpack(buf, ">H3")
    local len = ln + 6

    -- 取剩余数据
    if #buf < len then
        log.info("等待更多", len, #buf)
        local r, d = self.request:request(nil, len - #buf)
        if not r then
            return false, d
        end
        buf = buf .. d
    end

    return true, buf
end

-- 写入数据
-- @param slave integer 从站号
-- @param code integer 功能码
-- @param addr integer 地址
-- @param data string 数据
-- @return boolean 成功与否
function ModbusMaster:write(slave, code, addr, data)
    if code == 1 then
        code = 5
    elseif code == 3 or code == 4 then
        if #data > 2 then
            code = 16
        else
            code = 6
        end
    end

    if self.tcp then
        return self:writeTCP(slave, code, addr, data)
    end

    log.info("write", slave, code, addr, data)
    data = iot.pack("b2>H", slave, code, addr) .. data
    local crc = iot.pack('<H', modbus.crc16(data))

    local ret, buf = self.request:request(data .. crc, 7)
    if not ret then
        return false, buf
    end

    -- 取错误码
    if #buf > 3 then
        local code2 = string.byte(buf, 2)
        if code2 > 0x80 then
            log.error("错误码", code2)
            return false, "错误码" .. code2
        end
    end

    return true, buf
end

---打开主站
function ModbusMaster:open()
    if self.opened then
        log.error("已经打开")
        return
    end
    self.opened = true

    -- 加载设备
    -- local ds = devices.load_by_link(self.link.id)
    local ds = database.find("device", "link_id", self.link.id)

    -- 启动设备
    self.devices = {}
    for _, d in ipairs(ds) do
        log.info("open device", iot.json_encode(d))
        local dev = ModbusMasterDevice:new(d, self)
        dev:open() -- 设备也要打开

        self.devices[d.id] = dev

        devices.register(d.id, dev)
    end

    -- 开启轮询
    iot.start(ModbusMaster._polling, self)
end

--- 关闭
function ModbusMaster:close()
    self.opened = false
    self.devices = {}
end

--- 轮询
function ModbusMaster:_polling()

    -- 轮询间隔
    local interval = self.poller_interval or 60
    interval = interval * 1000 -- 毫秒

    while self.opened do
        log.info("轮询开始")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        for _, dev in pairs(self.devices) do

            -- 加入异常处理（pcall不能调用对象实例，只是用闭包了）
            local ret, info = utils.call(function()
                return dev:poll()
            end)
            if not ret then
                log.error("polling", dev.id, "error", info)
            end

            -- 避免太快
            iot.sleep(500)

        end

        local finish = mcu.ticks()
        local remain = interval - (finish - start)
        if remain > 0 then
            iot.sleep(remain)
        end
    end
end
