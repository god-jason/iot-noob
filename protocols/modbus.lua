--- Modbus 协议实现
-- @module modbus_device
local ModbusDevice = {}
ModbusDevice.__index = ModbusDevice

local tag = "modbus"

local Agent = require("agent")
local Device = require("device")
setmetatable(ModbusDevice, Device) -- 继承Device

local database = require("database")
local gateway = require("gateway")
local points = require("points")
local binary = require("binary")

local mapper_cache = {}

local function normalize_address(addr)
    if type(addr) == "string" then
        if addr:startsWith("H") or addr:startsWith("h") then
            local buf = binary.decodeHex(addr:sub(2))
            local num = 0
            for i = 1, #buf do
                num = num << 8
                num = num + string.byte(buf:sub(i))
            end
            addr = num
        else
            addr = tonumber(addr)
        end
    end
    return addr
end

-- 升序排列
local function sortPoint(pt1, pt2)
    return pt1.address < pt2.address
end

local function load_mapper(product_id)
    if mapper_cache[product_id] then
        return mapper_cache[product_id]
    end

    log.info(tag, "load mapper", product_id)

    local model = database.get("model", product_id)
    if not model then
        return nil
    end

    local mapper = {
        coils = {},
        discrete_inputs = {},
        holding_registers = {},
        input_registers = {},
        pollers = {}
    }

    log.info(tag, "load 2")

    -- 分类
    for _, prop in ipairs(model.properties or {}) do
        for _, pt in ipairs(prop.points) do
            if pt.register == 1 then
                table.insert(mapper.coils, pt)
            elseif pt.register == 2 then
                table.insert(mapper.discrete_inputs, pt)
            elseif pt.register == 3 then
                table.insert(mapper.holding_registers, pt)
            elseif pt.register == 4 then
                table.insert(mapper.input_registers, pt)
            end
        end
    end

    -- 兼容字符串地址
    for i, p in ipairs(mapper.coils) do
        p.address = normalize_address(p.address)
    end
    for i, p in ipairs(mapper.discrete_inputs) do
        p.address = normalize_address(p.address)
    end
    for i, p in ipairs(mapper.holding_registers) do
        p.address = normalize_address(p.address)
    end
    for i, p in ipairs(mapper.input_registers) do
        p.address = normalize_address(p.address)
    end

    -- 排序
    table.sort(mapper.coils, sortPoint)
    table.sort(mapper.discrete_inputs, sortPoint)
    table.sort(mapper.holding_registers, sortPoint)
    table.sort(mapper.input_registers, sortPoint)

    log.info(tag, "before pollers", iot.json_encode(mapper))

    -- 计算轮询
    if #(mapper.coils) > 0 then
        local begin = mapper.coils[1]
        local last = begin
        for i = 2, #(mapper.coils), 1 do
            if mapper.coils[i].address > last.address + 1 then
                table.insert(mapper.pollers, {
                    register = 1,
                    address = begin.address,
                    length = last.address - begin.address + 1
                })
                begin = mapper.coils[i]
            end
            last = mapper.coils[i]
        end
        table.insert(mapper.pollers, {
            register = 1,
            address = begin.address,
            length = last.address - begin.address + 1
        })
    end
    if #(mapper.discrete_inputs) > 0 then
        local begin = mapper.discrete_inputs[1]
        local last = begin
        for i = 2, #(mapper.discrete_inputs), 1 do
            if mapper.discrete_inputs[i].address > last.address + 1 then
                table.insert(mapper.pollers, {
                    register = 2,
                    address = begin.address,
                    length = last.address - begin.address + 1
                })
                begin = mapper.discrete_inputs[i]
            end
            last = mapper.discrete_inputs[i]
        end
        table.insert(mapper.pollers, {
            register = 2,
            address = begin.address,
            length = last.address - begin.address + 1
        })
    end
    if #(mapper.holding_registers) > 0 then
        local begin = mapper.holding_registers[1]
        local last = begin
        for i = 2, #(mapper.holding_registers), 1 do

            local feagure = points.feagure(last.type)
            if feagure then
                if mapper.holding_registers[i].address > last.address + feagure.word then
                    table.insert(mapper.pollers, {
                        register = 3,
                        address = begin.address,
                        length = last.address - begin.address + feagure.word
                    })
                    begin = mapper.holding_registers[i]
                end
            end

            last = mapper.holding_registers[i]
        end

        local feagure = points.feagure(last.type)
        if feagure then
            table.insert(mapper.pollers, {
                register = 3,
                address = begin.address,
                length = last.address - begin.address + feagure.word
            })
        end
    end
    if #(mapper.input_registers) > 0 then
        local begin = mapper.input_registers[1]
        local last = begin
        for i = 2, #(mapper.input_registers), 1 do

            local feagure = points.feagure(last.type)
            if feagure then
                if mapper.input_registers[i].address > last.address + feagure.word then
                    table.insert(mapper.pollers, {
                        register = 4,
                        address = begin.address,
                        length = last.address - begin.address + feagure.word
                    })
                    begin = mapper.input_registers[i]
                end
            end

            last = mapper.input_registers[i]
        end

        local feagure = points.feagure(last.type)
        if feagure then
            table.insert(mapper.pollers, {
                register = 4,
                address = begin.address,
                length = last.address - begin.address + feagure.word
            })
        end
    end

    log.info(tag, "pollers", iot.json_encode(mapper.pollers))

    mapper_cache[product_id] = mapper
    return mapper
end

---创建设备
-- @param obj table 设备参数
-- @param master Modbus 主站实例
-- @return Device 实例
function ModbusDevice:new(obj, master)
    local dev = setmetatable(Device:new(obj), self) -- 继承Device
    dev.master = master
    return dev
end

---打开设备
function ModbusDevice:open()
    log.info(tag, "device open", self.id, self.product_id)
    self.mapper = load_mapper(self.product_id)
end

---查找点位
-- @param key string 点位名称
-- @return boolean 成功与否
-- @return table 点位
function ModbusDevice:find_point(key)
    if not self.mapper then
        return false
    end
    for _, p in ipairs(self.mapper.coils) do
        if p.name == key then
            return true, p
        end
    end
    for _, p in ipairs(self.mapper.discrete_inputs) do
        if p.name == key then
            return true, p
        end
    end
    for _, p in ipairs(self.mapper.holding_registers) do
        if p.name == key then
            return true, p
        end
    end
    for _, p in ipairs(self.mapper.input_registers) do
        if p.name == key then
            return true, p
        end
    end
    return false
end

---读取数据
-- @param key string 点位
-- @return boolean 成功与否
-- @return any
function ModbusDevice:get(key)
    log.info(tag, "get", key, self.id)
    local ret, point = self:find_point(key)
    if not ret then
        return false
    end

    local data
    if point.register == 1 or point.register == 2 then
        ret, data = self.master:read(self.station.slave, point.register, point.address, 1)
        if not ret then
            return false
        end
        -- 直接判断返回值就行了 FF00 0000
        ret, data = points.parseBit(point, data, point.address)
    elseif point.register == 3 or point.register == 4 then
        local feagure = points.feature(point.type)
        if not feagure then
            return false
        end
        ret, data = self.master:read(self.station.slave, point.register, point.address, feagure.word)
        if not ret then
            return false
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
function ModbusDevice:set(key, value)
    log.info(tag, "set", key, value, self.id)
    local ret, point = self:find_point(key)
    if not ret then
        return false
    end

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
            return false
        end
        code = 6
    end

    return self.master:write(self.station.slave, code, point.address, data)
end

---读取所有数据
function ModbusDevice:poll()
    log.info(tag, "poll", self.id)
    -- log.info(tag, "poller", iot.json_encode(self.options.pollers))

    -- 没有轮询器，直接返回
    if not self.mapper.pollers or #self.mapper.pollers == 0 then
        log.info(tag, self.id, self.product_id, "pollers empty")
        return false
    end

    for _, poller in ipairs(self.mapper.pollers) do
        local res, data = self.master:read(self.slave, poller.register, poller.address, poller.length)
        if res then
            log.info(tag, "poll read", #data)

            if poller.register == 1 then
                -- log.info(tag, "parse 1 ", #data)
                for _, point in ipairs(self.mapper.coils) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseBit(point, data, poller.address)
                        if r then
                            self:put_value(point.name, v)
                        end
                    end
                end
                -- log.info(tag, "parse 1 ", iot.json_encode(values))
            elseif poller.register == 2 then
                -- log.info(tag, "parse 2 ", #data)
                for _, point in ipairs(self.mapper.discrete_inputs) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseBit(point, data, poller.address)
                        if r then
                            self:put_value(point.name, v)
                        end
                    end
                end
                -- log.info(tag, "parse 2 ", iot.json_encode(values))
            elseif poller.register == 3 then
                -- log.info(tag, "parse 3 ", #data)
                for _, point in ipairs(self.mapper.holding_registers) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseWord(point, data, poller.address)
                        if r then
                            self:put_value(point.name, v)
                        end
                    end
                end
                -- log.info(tag, "parse 3 ", iot.json_encode(values))
            elseif poller.register == 4 then
                -- log.info(tag, "parse 4 ", #data)
                for _, point in ipairs(self.mapper.input_registers) do
                    if poller.address <= point.address and point.address < poller.address + poller.length then
                        local r, v = points.parseWord(point, data, poller.address)
                        if r then
                            self:put_value(point.name, v)
                        end
                    end
                end
                -- log.info(tag, "parse 4 ", iot.json_encode(values))
            else
                log.error(tag, "unkown code ", poller.code)
                -- 暂不支持其他类型
            end
        else
            log.error(tag, "poll read failed")
        end
    end
end

---Modbus主站
-- @module modbus_master
local ModbusMaster = {}
ModbusMaster.__index = ModbusMaster

gateway.register_protocol("modbus", ModbusMaster)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Master
function ModbusMaster:new(link, opts)
    local master = setmetatable({}, self)
    master.link = link
    master.timeout = opts.timeout or 1000 -- 1秒钟
    master.agent = Agent:new(link, master.timeout)
    master.poller_interval = opts.poller_interval or 5 -- 5秒钟
    master.tcp = opts.tcp or false -- modbus tcp
    master.increment = 1 -- modbus-tcp序号

    return master
end

function ModbusMaster:readTCP(slave, code, addr, len)
    log.info(tag, "readTCP", slave, code, addr, len)

    local data = iot.pack("b2>H2", slave, code, addr, len)
    -- 事务ID, 0000, 长度
    local header = iot.pack(">H3", self.increment, 0, #data)
    self.increment = self.increment + 1

    local ret, buf = self.agent:ask(header .. data, 12)
    if not ret then
        return false
    end

    -- 取错误码
    if #buf > 8 then
        local code2 = string.byte(buf, 8)
        if code2 > 0x80 then
            log.error(tag, "error code", code2)
            return false
        end
    end

    -- 解析包头
    local _, _, ln = iot.unpack(buf, ">H3")
    len = ln + 6

    -- 取剩余数据
    if #buf < len then
        log.info(tag, "wait more", len, #buf)
        local r, d = self.agent:ask(nil, len - #buf)
        if not r then
            return false
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

    log.info(tag, "read", slave, code, addr, len)

    local data = iot.pack("b2>H2", slave, code, addr, len)
    local crc = iot.pack('<H', crypto.crc16_modbus(data))

    local ret, buf = self.agent:ask(data .. crc, 7)
    if not ret then
        return false
    end

    -- 取错误码
    if #buf > 3 then
        local code2 = string.byte(buf, 2)
        if code2 > 0x80 then
            log.error(tag, "error code", code2)
            return false
        end
    end

    -- 先取字节数
    local cnt = string.byte(buf, 3)
    local len2 = 5 + cnt
    if #buf < len2 then
        log.info(tag, "wait more", len2, #buf)
        local r, d = self.agent:ask(nil, len2 - #buf)
        if not r then
            return false
        end
        buf = buf .. d
    end

    return true, string.sub(buf, 4, len2 - 2)
end

function ModbusMaster:writeTCP(slave, code, addr, data)
    log.info(tag, "writeTCP", slave, code, addr, data)

    data = iot.pack("b2>H", slave, code, addr) .. data

    -- 事务ID, 0000, 长度
    local header = iot.pack(">H3", self.increment, 0, #data)
    self.increment = self.increment + 1

    local ret, buf = self.agent:ask(header .. data, 12)
    if not ret then
        return false
    end

    -- 取错误码
    if #buf > 8 then
        local code2 = string.byte(buf, 8)
        if code2 > 0x80 then
            log.error(tag, "error code", code2)
            return false
        end
    end

    -- 解析包头
    local _, _, ln = iot.unpack(buf, ">H3")
    local len = ln + 6

    -- 取剩余数据
    if #buf < len then
        log.info(tag, "wait more", len, #buf)
        local r, d = self.agent:ask(nil, len - #buf)
        if not r then
            return false
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
        if data then
            data = 0xFF00
        else
            data = 0x0000
        end
    elseif code == 3 then
        -- data = iot.pack('>H', data) --大端数据
        if #data > 2 then
            code = 16
        else
            code = 6
        end
    end

    if self.tcp then
        return self:writeTCP(slave, code, addr, data)
    end

    log.info(tag, "write", slave, code, addr, data)
    data = iot.pack("b2>H", slave, code, addr) .. data
    local crc = iot.pack('<H', crypto.crc16_modbus(data))

    local ret, buf = self.agent:ask(data .. crc, 7)
    if not ret then
        return false
    end

    -- 取错误码
    if #buf > 3 then
        local code2 = string.byte(buf, 2)
        if code2 > 0x80 then
            log.error(tag, "error code", code2)
            return false
        end
    end

    return true, buf
end

---打开主站
function ModbusMaster:open()
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
        local dev = ModbusDevice:new(d, self)
        dev:open() -- 设备也要打开

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
        log.info(tag, "polling start")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        for _, dev in pairs(self.devices) do

            -- 加入异常处理（pcall不能调用对象实例，只是用闭包了）
            local ret, info = pcall(function()

                local ret, values = dev:poll()
                if ret then
                    log.info(tag, "polling", dev.id, "succeed")
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
            iot.sleep(remain)
        end
    end
end
