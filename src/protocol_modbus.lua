--- Modbus协议实现
--- @module "Mobus"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "modbus"

local devices = require("devices")
local products = require("products")
local points = require("points")
local cloud = require("cloud")

--- 设备类
--- @class Device
local Device = {}

---创建设备
---@param master Modbus 主站实例
---@param dev table 设备参数
---@return Device 实例
function Device:new(master, dev)
    local obj = dev or {}
    setmetatable(obj, self)
    self.__index = self
    obj.master = master
    return obj
end

---打开设备
function Device:open()
    log.info(tag, "device open", self.id, self.product_id)

    local ret
    ret, self.options = products.load_config(self.product_id, "modbus")
    if not ret then
        log.error(tag, self.product_id, "modbus_mapper load failed")
    end
end

---查找点位
---@param key string 点位名称
---@return boolean 成功与否
---@return table 点位
---@return integer 功能码
function Device:_find_point(key)
    if not self.options or not self.options.mapper then
        return false
    end
    for _, p in ipairs(self.options.mapper.coils) do
        if p.name == key then
            return true, p, 1
        end
    end
    for _, p in ipairs(self.options.mapper.discrete_inputs) do
        if p.name == key then
            return true, p, 2
        end
    end
    for _, p in ipairs(self.options.mapper.holding_registers) do
        if p.name == key then
            return true, p, 3
        end
    end
    for _, p in ipairs(self.options.mapper.input_registers) do
        if p.name == key then
            return true, p, 4
        end
    end
    return false
end

---读取数据
---@param key string 点位
---@return boolean 成功与否
---@return any
function Device:get(key)
    log.info(tag, "get", key, self.id)
    local ret, point, code = self:_find_point(key)
    if not ret then
        return false
    end

    local data
    if code == 1 or code == 2 then
        ret, data = self.master:read(self.station.slave, code, point.address, 1)
        if not ret then
            return false
        end
        -- 直接判断返回值就行了 FF00 0000
        return true, points.parseBit(point, data, point.address)
    else
        local feagure = points.feature(point.type)
        if not feagure then
            return false
        end
        ret, data = self.master:read(self.station.slave, code, point.address, feagure.word)
        if not ret then
            return false
        end
        return true, points.parseWord(point, data, point.address)
    end
end

---读取数据
---@param key string 点位
---@param value any 值
---@return boolean 成功与否
function Device:set(key, value)
    log.info(tag, "set", key, value, self.id)
    local ret, point, code = self:_find_point(key)
    if not ret then
        return false
    end

    local data

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
            return false
        end
        code = 6
    end

    return self.master:write(self.station.slave, code, point.address, data)
end

---读取所有数据
---@return boolean 成功与否
---@return table|nil 值
function Device:poll()
    log.info(tag, "poll", self.id)
    -- log.info(tag, "poller", json.encode(self.options.pollers))

    -- 没有轮询器，直接返回
    if not self.options or not self.options.pollers or #self.options.pollers == 0 then
        log.info(tag, self.id, self.product_id, "pollers empty")
        return false
    end

    local ret = false
    local values = {}
    for _, poller in ipairs(self.options.pollers) do
        local res, data = self.master:read(self.station.slave, poller.code, poller.address, poller.length)
        if res then
            log.info(tag, "poll read", #data)

            if poller.code == 1 then
                -- log.info(tag, "parse 1 ", #data)
                for _, point in ipairs(self.options.mapper.coils) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseBit(point, data, poller.address)
                        if r then
                            ret = true
                            values[point.name] = v
                        end
                    end
                end
                -- log.info(tag, "parse 1 ", json.encode(values))
            elseif poller.code == 2 then
                -- log.info(tag, "parse 2 ", #data)
                for _, point in ipairs(self.options.mapper.discrete_inputs) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseBit(point, data, poller.address)
                        if r then
                            ret = true
                            values[point.name] = v
                        end
                    end
                end
                -- log.info(tag, "parse 2 ", json.encode(values))
            elseif poller.code == 3 then
                -- log.info(tag, "parse 3 ", #data)
                for _, point in ipairs(self.options.mapper.holding_registers) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseWord(point, data, poller.address)
                        if r then
                            ret = true
                            values[point.name] = v
                        end
                    end
                end
                -- log.info(tag, "parse 3 ", json.encode(values))
            elseif poller.code == 4 then
                -- log.info(tag, "parse 4 ", #data)
                for _, point in ipairs(self.options.mapper.input_registers) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseWord(point, data, poller.address)
                        if r then
                            ret = true
                            values[point.name] = v
                        end
                    end
                end
                -- log.info(tag, "parse 4 ", json.encode(values))
            else
                log.info(tag, "unkown code ", poller.code)
                -- 暂不支持其他类型
            end
        else
            log.info(tag, "poll read failed")
        end
    end
    return ret, values
end

---Modbus Master 类型
---@class Modbus
local Modbus = {}

require("protocols").register("modbus-rtu", Modbus)

---创建实例
---@param link any 连接实例
---@param opts table 协议参数
---@return Modbus
function Modbus:new(link, opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.link = link
    obj.timeout = opts.timeout or 1000 -- 1秒钟
    obj.poller_interval = opts.poller_interval or 5 -- 5秒钟

    return obj
end

---询问
---@param request string 发送数据
---@param len integer 期望长度
---@return boolean 成功与否
---@return string 返回数据
function Modbus:ask(request, len)
    -- log.info(tag, "ask", request, len)
    if request ~= nil and #request > 0 then
        local ret = self.link:write(request)
        if not ret then
            log.info(tag, "write failed")
            return false
        end
    end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    repeat
        -- TODO 应该不是每次都要等待
        local ret = self.link:wait(self.timeout)
        if not ret then
            log.info(tag, "read timeout")
            return false
        end

        local r, d = self.link:read()
        if not r then
            log.info(tag, "read failed")
            return false
        end
        buf = buf .. d
    until #buf >= len

    return true, buf
end

-- 读取数据
---@param slave integer 从站号
---@param code integer 功能码
---@param addr integer 地址
---@param len integer 长度
---@return boolean 成功与否
---@return string 只有数据
function Modbus:read(slave, code, addr, len)
    log.info(tag, "read", slave, code, addr, len)

    -- local data = (string.format("%02x",slave)..string.format("%02x",code)..string.format("%04x",offset)..string.format("%04x",length)):fromHex()
    local data = pack.pack("b2>H2", slave, code, addr, len)
    local crc = pack.pack('<H', crypto.crc16_modbus(data))

    local ret, buf = self:ask(data .. crc, 7)
    if not ret then
        return false
    end

    -- 取错误码
    if #buf > 3 then
        local code = string.byte(buf, 2)
        if code > 0x80 then
            log.info(tag, "error code", code)
            return false
        end
    end

    -- 先取字节数
    local cnt = string.byte(buf, 3)
    local len = 5 + cnt
    if #buf < len then
        log.info(tag, "wait more", len, #buf)
        local r, d = self:ask(nil, len - #buf)
        if not r then
            return false
        end
        buf = buf .. d
    end

    return true, string.sub(buf, 4, len - 2)
end

-- 写入数据
---@param slave integer 从站号
---@param code integer 功能码
---@param addr integer 地址
---@param data string 数据
---@return boolean 成功与否
function Modbus:write(slave, code, addr, data)
    if code == 1 then
        code = 5
        if data then
            data = 0xFF00
        else
            data = 0x0000
        end
    elseif code == 3 then
        -- data = pack.pack('>H', data) --大端数据
        if #data > 2 then
            code = 16
        else
            code = 6
        end
    end

    log.info(tag, "write", slave, code, addr, data)
    local data = pack.pack("b2>H", slave, code, addr) .. data
    local crc = pack.pack('<H', crypto.crc16_modbus(data))

    local ret, buf = self:ask(data .. crc, 7)
    if not ret then
        return false
    end

    -- 取错误码
    if #buf > 3 then
        local code = string.byte(buf, 2)
        if code > 0x80 then
            log.info(tag, "error code", code)
            return false
        end
    end

    return true
end

---打开主站
function Modbus:open()
    if self.opened then
        log.info(tag, "already opened")
        return
    end
    self.opened = true

    -- 加载设备
    local ds = devices.load_by_link(self.link.id)

    -- 启动设备
    self.devices = {}
    for _, d in ipairs(ds) do
        log.info(tag, "open device", json.encode(d))
        local dev = Device:new(self, d)
        dev:open() -- 设备也要打开

        self.devices[d.id] = dev
        -- dev.open()
        devices.set(d.id, dev)
    end

    -- 开启轮询
    local this = self
    self.task = sys.taskInit(function()
        this:_polling()
    end)
end

--- 关闭
function Modbus:close()
    self.opened = false
    self.devices = {}
end

--- 轮询
function Modbus:_polling()
    -- 轮询间隔 TODO 计时，算时差
    local interval = self.poller_interval or 60

    while self.opened do
        log.info(tag, "polling start")
        local start = os.clock()

        for _, dev in pairs(self.devices) do
            local ret, values = dev:poll()
            if ret then
                log.info(tag, "polling", dev.id, "succeed")
                -- log.info(tag, "polling", dev.id, "values", json.encode(values))
                -- 向平台发布消息
                -- cloud.publish("device/" .. dev.product_id .. "/" .. dev.id .. "/property", values)
                sys.publish("DEVICE_VALUES", dev, values)
            else
                log.info(tag, "polling", dev.id, "failed")
            end
        end

        local finish = os.clock()
        local remain = interval - (finish - start)

        if remain > 0 then
            sys.wait(remain * 1000)
        end
    end
end
