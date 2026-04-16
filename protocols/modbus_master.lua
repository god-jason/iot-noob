--- Modbus 协议实现
-- @module modbus_master_device
local modbus_master = {}


local log = iot.logger("modbus_master")

local Request = require("request")
local database = require("database")
local devices = require("devices")
local protocols = require("protocols")
local points = require("points")
local model = require("model")
local modbus = require("modbus")
local utils = require("utils")

--- Modbus设备
-- @module modbus_master_device
local ModbusMasterDevice = utils.class(require("device"))
modbus_master.ModbusMasterDevice = ModbusMasterDevice


---打开设备
function ModbusMasterDevice:open()
    log.info("device open", self.id, self.product_id)
    self.mapper = modbus.load_mapper(self.product_id)

    -- TODO 优化
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
        ret, data = points.parseBit(point, data, point.address)
    elseif point.register == 3 or point.register == 4 then
        local feature = points.feature(point.type)
        if not feature then
            return false, "找不到类型"
        end
        ret, data = self.master:read(self.slave, point.register, point.address, feature.word)
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

    if value == nil then
        return false, "值不能为空"
    end

    local ret
    local data
    local func = point.register

    -- 编码数据
    if func == 1 or func == 2 then
        -- 兼容 false 0
        if value == false or value <= 0 then
            data = string.fromHex("0000")
        else
            data = string.fromHex("FF00")
        end
        func = 5
    else
        ret, data = points.encode(point, value)
        if not ret then
            return false, data
        end
        func = 6
    end

    return self.master:write(self.slave, func, point.address, data)
end

---读取所有数据
function ModbusMasterDevice:poll()
    log.info("poll", self.id)
    -- log.info("poller", iot.json_encode(self.options.pollers))

    -- 没有轮询器，直接返回
    if not self.mapper.pollers or #self.mapper.pollers == 0 then
        return false, "没有轮询器" .. self.product_id
    end

    -- 依次轮询
    for _, poller in ipairs(self.mapper.pollers) do
        log.info("poll", self.slave, poller.register, poller.address, poller.length)

        local res, data = self.master:read(self.slave, poller.register, poller.address, poller.length)
        if res then
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
local ModbusMaster = utils.class()
protocols.register("modbus", ModbusMaster)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Master
function ModbusMaster:init()
    self.link = self.link
    self.devices = self.devices or {}
    self.timeout = self.timeout or 1000 -- 1秒钟
    self.request = Request:new(self.link, self.timeout)
    self.polling_interval = self.polling_interval or 5 -- 5秒钟
    self.tcp = self.tcp or false -- modbus tcp
    self.increment = 1 -- modbus-tcp序号
end

function ModbusMaster:readTCP(slave, func, addr, len)
    log.info("readTCP", slave, func, addr, len)

    local data = iot.pack("b2>H2", slave, func, addr, len)
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
-- @param func integer 功能码
-- @param addr integer 地址
-- @param len integer 长度
-- @return boolean 成功与否
-- @return string 只有数据
function ModbusMaster:read(slave, func, addr, len)
    if self.tcp then
        return self:readTCP(slave, func, addr, len)
    end

    log.info("read", slave, func, addr, len)

    local data = iot.pack("b2>H2", slave, func, addr, len)
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

function ModbusMaster:writeTCP(slave, func, addr, data)
    log.info("writeTCP", slave, func, addr, data)

    data = iot.pack("b2>H", slave, func, addr) .. data

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
-- @param func integer 功能码
-- @param addr integer 地址
-- @param data string 数据
-- @return boolean 成功与否
function ModbusMaster:write(slave, func, addr, data)
    if func == 1 then
        func = 5
    elseif func == 3 or func == 4 then
        if #data > 2 then
            func = 16
        else
            func = 6
        end
    end

    if self.tcp then
        return self:writeTCP(slave, func, addr, data)
    end

    log.info("write", slave, func, addr, data)
    data = iot.pack("b2>H", slave, func, addr) .. data
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
        return false, "已经打开了"
    end
    self.opened = true

    -- 启动设备
    for i, d in ipairs(self.devices) do
        log.info("open device", iot.json_encode(d))
        local dev = ModbusMasterDevice:new(d)
        dev.master = self
        dev:open() -- 设备也要打开

        devices.register(d.id, dev)
    end

    -- 轮询
    if self.polling ~= false then
        iot.start(DLT645Master.polling_task, self)
    end

    return true
end

--- 关闭
function ModbusMaster:close()
    self.opened = false
    self.devices = {}
end


function ModbusMaster:polling_all()
    -- 轮询连接下面的所有设备
    for _, dev in pairs(self.devices) do

        -- 至多轮询3次
        for i = 1, 3, 1 do
            local ret, result = iot.xcall(dev.poll, dev)
            if ret then
                break
            else
                log.error(dev.id, "轮询错误", result)
            end
        end
        -- 避免太快
        iot.sleep(500)
    end
end

--- 轮询
function ModbusMaster:polling_task()
    log.info("polling thread start")

    local delay = self.polling_delay or 5
    if delay > 0 then
        iot.sleep(delay * 1000)
    end

    -- 轮询间隔
    local interval = self.polling_interval or 60
    interval = interval * 1000 -- 毫秒

    log.info("polling interval", interval)

    while self.opened do
        log.info("polling start")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        self:polling_all()

        local finish = mcu.ticks()
        local remain = interval - (finish - start)
        if remain > 0 then
            iot.sleep(remain)
        end
    end
end

return modbus_master