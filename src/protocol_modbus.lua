local tag = "modbus"


local devices = require("devices")
local products = require("products")
local points = require("points")


local Device = {}

function Device:new(master, dev)
    local obj = dev or {}
    setmetatable(obj, self)
    self.__index = self
    obj.master = master
    return obj
end

function Device:open()
    self.mapper = products.load(self.product_id, "modbus_mapper")
    self.poller = products.load(self.product_id, "modbus_poller")
end

function Device:find_point(key)
    if not self.mapper then return false end
    for _, p in ipairs(self.mapper.coils) do
        if p.name == key then
            return true, p, 1
        end
    end
    for _, p in ipairs(self.mapper.discrete_inputs) do
        if p.name == key then
            return true, p, 2
        end
    end
    for _, p in ipairs(self.mapper.holding_registers) do
        if p.name == key then
            return true, p, 3
        end
    end
    for _, p in ipairs(self.mapper.input_registers) do
        if p.name == key then
            return true, p, 4
        end
    end
    return false
end

function Device:get(key)
    local ret, point, code = self:find_point(key)
    if not ret then return false end
    local feagure = points.feature[point.type]
    if not feagure then return false end
    local res, data = self.master:read(self.slave, code, point.address, feagure.size)
    if not res then return res end

    --解析数据
    local be = point.be and ">" or "<"
    local pk = feagure.pack
    local _, val = pack.unpack(data, be .. pk)
    return true, val
end

function Device:set(key, value)
    local ret, point, code = self:find_point(key)
    if not ret then return false end

    local data

    --编码数据
    if code == 1 or code == 2 then
        if value then
            data = string.fromHex("FF00")
        else
            data = string.fromHex("0000")
        end
    else
        local feagure = points.feature[point.type]
        if not feagure then return false end
        local be = point.be and ">" or "<"
        local pk = feagure.pack
        data = pack.pack(be .. pk, value)
    end

    return self.master:write(self.slave, code, point.address, data)
end

function Device:poll()
    local ret = false
    local values = {}
    for _, poller in ipairs(self.poller.pollers) do
        local res, data = self.master:read(self.slave, poller.code, poller.address, poller.length)
        if res then
            if poller.code == 1 then
                for _, point in ipairs(self.mapper.coils) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local offset = point.address - poller.address + 1
                        local byte = string.byte(data, math.floor(offset / 8))
                        local value = bit.isSet(byte, offset % 8)
                        values[point.name] = value
                        return true
                    end
                end
            elseif poller.code == 2 then
                for _, point in ipairs(self.mapper.discrete_inputs) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local offset = point.address - poller.address + 1
                        local byte = string.byte(data, math.floor(offset / 8))
                        local value = bit.isSet(byte, offset % 8)
                        values[point.name] = value
                        return true
                    end
                end
            elseif poller.code == 3 then
                for _, point in ipairs(self.mapper.holding_registers) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local feagure = points.feature[point.type]
                        if feagure then
                            --编码数据
                            local be = point.be and ">" or "<"
                            local pk = feagure.pack
                            local buf = string.sub(data, (point.address - poller.address) * 2 + 1) --lua索引从1开始...
                            local _, value = pack.unpack(buf, be .. pk)
                            values[point.name] = value
                            return true
                        end
                    end
                end
            elseif poller.code == 4 then
                for _, point in ipairs(self.mapper.input_registers) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local feagure = points.feature[point.type]
                        if feagure then
                            --编码数据
                            local be = point.be and ">" or "<"
                            local pk = feagure.pack
                            local buf = string.sub(data, (point.address - poller.address) * 2 + 1) --lua索引从1开始...
                            local _, value = pack.unpack(buf, be .. pk)
                            values[point.name] = value
                            return true
                        end
                    end
                end
            else
            end
        end
    end
    return ret, values
end

local Modbus = {}
require("protocols").register("modbus-rtu", Modbus)

function Modbus:new(link, opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.link = link
    obj.timeout = opts.timeout or 1000
    return obj
end

function Modbus:ask(request, len)
    if not request then
        local ret = self.link:write(request)
        if not ret then return false end
    end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    repeat
        --TODO 应该不是每次都要等待
        local ret = self.link:wait(self.timeout)
        if not ret then
            log.info(tag, "read timeout")
            return false
        end

        local r, d = self.link:read()
        if not r then return false end
        buf = buf .. d

        if #buf > 3 then
            -- 取错误码
            local code = string.byte(buf, 2)
            if code > 0x80 then
                log.info(tag, "error", code, string.byte(3))
                return false
            end
        end
    until #buf >= len

    return true, buf
end

-- 读取数据
function Modbus:read(slave, code, addr, len)
    -- local data = (string.format("%02x",slave)..string.format("%02x",code)..string.format("%04x",offset)..string.format("%04x",length)):fromHex()
    local data = pack.pack("b2>H2", slave, code, addr, len)
    local crc = pack.pack('<h', crypto.crc16_modbus(data))

    local ret, buf = self:ask(data .. crc, 7)
    if not ret then return false end

    --先取字节数
    local cnt = string.byte(3)
    local len = 5 + cnt
    if #buf < len then
        local r, d = self:ask(nil, len - #buf)
        if not r then return false end
        buf = buf .. d
    end

    return true, string.sub(buf, 4, len - 2)
end

-- 写入数据
function Modbus:write(slave, code, addr, data)
    if code == 1 then
        code = 5
        if data then data = 0xFF00 else data = 0x0000 end
    elseif code == 3 then
        -- data = pack.pack('>H', data) --大端数据
        if #data > 2 then code = 16 else code = 6 end
    end

    local data = pack.pack("b2>H", slave, code, addr) .. data
    local crc = pack.pack('<H', crypto.crc16_modbus(data))

    local ret, buf = self:ask(data .. crc, 7)
    if not ret then return false end

    return true
end

function Modbus:open()
    if self.opened then
        log.info(tag, "already opened")
        return
    end
    self.opened = true

    --加载设备
    local ret, ds = devices.load_by_link(self.link.id)
    if not ret then return end

    --启动设备
    self.devices = {}
    for _, d in ipairs(ds) do
        local dev = Device:new(self, d)
        self.devices[d.id] = dev
        dev.open()
    end

    --开启轮询
    self.task = sys.taskInit(function() self:_polling() end)
end

function Modbus:close()
    self.opened = false
    self.devices = {}
end

function Modbus:_polling()
    while self.opened do
        for _, dev in pairs(self.devices) do
            local ret, values = dev:poll()
            if ret then
                --TODO 发布MQTT消息
                log.info(tag, dev.id, "values", values)
            end
        end

        -- 轮询间隔
        if self.poller_interval > 0 then
            sys.wait(self.poller_interval * 1000)
        else
            sys.wait(60 * 1000)
        end
    end
end
