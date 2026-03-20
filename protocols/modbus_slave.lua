--- Modbus 协议实现
-- @module modbus_slave_device
local ModbusSlaveDevice = {}
ModbusSlaveDevice.__index = ModbusSlaveDevice

local log = iot.logger("modbus_slave")

local Request = require("request")
local Device = require("device")
setmetatable(ModbusSlaveDevice, Device) -- 继承Device

local database = require("database")
local devices = require("devices")
local protocols = require("protocols")
local points = require("points")
local model = require("model")
local utils = require("utils")
local modbus = require("modbus")

---创建设备
-- @param obj table 设备参数
-- @param slave Modbus 主站实例
-- @return Device 实例
function ModbusSlaveDevice:new(obj, slave)
    local dev = setmetatable(Device:new(obj), self) -- 继承Device
    dev.slave = slave
    dev.coils = {}
    dev.discrete_inputs = {}
    dev.holding_registers = {}
    dev.input_registers = {}
    return dev
end

---打开设备
function ModbusSlaveDevice:open()
    log.info("device open", self.id, self.product_id)
    self.mapper = modbus.load_mapper(self.product_id)
end

---写入数据
-- @param key string 点位
-- @param value any 值
-- @return boolean 成功与否
function ModbusSlaveDevice:set(key, value)
    log.info("set", key, value, self.id)
    self._values[key] = value

    local point = self.mapper:find(key)
    if not point then
        return false, "找不到点位" .. key
    end

    -- 写入寄存器缓存
    if point.register == 1 then
        self.coils[point.address] = value == true
    elseif point.register == 2 then
        self.discrete_inputs[point.address] = value == true
    elseif point.register == 3 then
        local ret, data = points.encode(point, value)
        if not ret then
            return false, data
        end
        for i = 1, #data, 2 do
            self.holding_registers[point.address + (i - 1) / 2] = data:sub(i, i + 1)
        end
    elseif point.register == 4 then
        local ret, data = points.encode(point, value)
        if not ret then
            return false, data
        end
        for i = 1, #data, 2 do
            self.input_registers[point.address + (i - 1) / 2] = data:sub(i, i + 1)
        end
    else
        return false, "未支持的寄存器类型"
    end
    return true
end

--- 生成异常响应
function ModbusSlaveDevice:exception(func, code)
    local resp = string.char(self.slave, func | 0x80, code)
    local crc = modbus.crc16(resp)
    return resp .. iot.pack("<H", crc)
end

--- 构建标准响应（RTU）
function ModbusSlaveDevice:build_response(func, payload)
    local resp = string.char(self.slave, func) .. payload
    local crc = modbus.crc16(resp)
    return resp .. iot.pack("<H", crc)
end

--- 读取线圈
function ModbusSlaveDevice:read_coils(data)
    local _, addr, len = iot.unpack("2>H", data, 3)

    --  处理1个长度
    if len == 1 then
        if self.coils[addr] then
            return self:build_response(2, string.char(2) .. "\xFF00")
        else
            return self:build_response(2, string.char(2) .. "\x0000")
        end
    end

    local payload = {}
    for i = 0, len - 1 do
        local v = self.coils[addr + i] and 1 or 0
        table.insert(payload, v)
    end

    -- 转换成字节数组
    local byte_cnt = math.ceil(#payload / 8)
    local bytes = {}
    for i = 1, byte_cnt do
        local b = 0
        for bit = 0, 7 do
            local idx = (i - 1) * 8 + bit + 1
            if payload[idx] then
                b = b | (payload[idx] << bit)
            end
        end
        table.insert(bytes, string.char(b))
    end

    return self:build_response(1, string.char(byte_cnt) .. table.concat(bytes))
end

--- 读取离散输入（只读，类似 coils）
function ModbusSlaveDevice:read_discrete_inputs(data)
    local _, addr, len = iot.unpack("2>H", data, 3)

    -- 处理1个长度
    if len == 1 then
        if self.discrete_inputs[addr] then
            return self:build_response(2, string.char(2) .. "\xFF00")
        else
            return self:build_response(2, string.char(2) .. "\x0000")
        end
    end

    local payload = {}
    for i = 0, len - 1 do
        local v = self.discrete_inputs[addr + i] and 1 or 0
        table.insert(payload, v)
    end

    local byte_cnt = math.ceil(#payload / 8)
    local bytes = {}
    for i = 1, byte_cnt do
        local b = 0
        for bit = 0, 7 do
            local idx = (i - 1) * 8 + bit + 1
            if payload[idx] then
                b = b | (payload[idx] << bit)
            end
        end
        table.insert(bytes, string.char(b))
    end

    return self:build_response(2, string.char(byte_cnt) .. table.concat(bytes))
end

--- 读取保持寄存器
function ModbusSlaveDevice:read_holding_registers(data)
    local _, addr, len = iot.unpack("2>H", data, 3)

    local bytes = {}
    for i = 0, len - 1 do
        local val = self.holding_registers[addr + i] or "0000"
        table.insert(bytes, val)
    end

    return self:build_response(3, string.char(len * 2) .. table.concat(bytes))
end

--- 读取输入寄存器
function ModbusSlaveDevice:read_input_registers(data)
    local _, addr, len = iot.unpack("2>H", data, 3)

    local bytes = {}
    for i = 0, len - 1 do
        local val = self.input_registers[addr + i] or "0000"
        table.insert(bytes, val)
    end

    return self:build_response(4, string.char(len * 2) .. table.concat(bytes))
end

--- 写单个线圈
function ModbusSlaveDevice:write_coil(data)
    local _, addr, val = iot.unpack("2>H", data, 3)
    local val = val == 0xFF00

    if self.coils[addr] == nil then
        return self:exception(5, 2) -- 非法地址
    end

    self.coils[addr] = val

    -- 找到变量，put_value
    for i, point in ipairs(self.mapper.coils) do
        if point.address == addr then
            self:put_value(point.name, val)
            break
        end
    end

    -- return self:build_response(5, data:sub(3, 6))
    return data
end

--- 写单个寄存器
function ModbusSlaveDevice:write_register(data)
    local _, addr = iot.unpack(">H", data, 3)

    if self.holding_registers[addr] == nil then
        return self:exception(6, 2)
    end

    self.holding_registers[addr] = data:sub(5, 6)

    -- 找到变量，put_value
    for i, point in ipairs(self.mapper.holding_registers) do
        if point.address == addr then
            local ret, val = points.parseWord(point, data:sub(5), point.address)
            if ret then
                self:put_value(point.name, val)
            end
            break
        end
    end

    --return self:build_response(6, data:sub(3, 6))
    return data
end

--- 写多个线圈
function ModbusSlaveDevice:write_multiple_coils(data)
    local _, addr, len = iot.unpack("2>H", data, 3)
    local byte_cnt = string.byte(data, 7)
    local coil_bytes = data:sub(8, 7 + byte_cnt)

    for i = 0, len - 1 do
        local byte_idx = math.floor(i / 8) + 1
        local bit_idx = i % 8
        local bit_val = (string.byte(coil_bytes, byte_idx) >> bit_idx) & 0x01
        self.coils[addr + i] = bit_val == 1
    end

    -- 找到变量，put_values
    local has = false
    local values = {}
    for i, point in ipairs(self.mapper.coils) do
        if point.address >= addr and point.address < addr + coil_bytes then
            values[point.name] = self.coils[point.address]
            has = true
        end
    end
    if has then
        self:put_values(values)
    end

    return self:build_response(15, data:sub(3, 7))
end

--- 写多个寄存器
function ModbusSlaveDevice:write_multiple_registers(data)
    local _, addr, len = iot.unpack("2>H", data, 3)
    local byte_cnt = string.byte(data, 7)
    local reg_bytes = data:sub(8, 7 + byte_cnt)

    for i = 0, len - 1 do
        self.holding_registers[addr + i] = reg_bytes:sub(2 * i + 1, 2 * i + 2)
    end

    -- 找到变量，put_values
    local has = false
    local values = {}
    for i, point in ipairs(self.mapper.holding_registers) do
        if point.address >= addr and point.address < addr + reg_bytes then
            local ret, val = points.parseWord(point, reg_bytes, addr)
            if ret then
                values[point.name] = val
                has = true
            end
        end
    end
    if has then
        self:put_values(values)
    end

    return self:build_response(16, data:sub(3, 6))
end

--- 主处理函数
function ModbusSlaveDevice:process(data)
    local slave = string.byte(data, 1)
    local func = string.byte(data, 2)

    if slave ~= self.slave then
        return nil -- 非本从站的数据
    end

    if func == 1 then
        return self:read_coils(data)
    elseif func == 2 then
        return self:read_discrete_inputs(data)
    elseif func == 3 then
        return self:read_holding_registers(data)
    elseif func == 4 then
        return self:read_input_registers(data)
    elseif func == 5 then
        return self:write_coil(data)
    elseif func == 6 then
        return self:write_register(data)
    elseif func == 15 then
        return self:write_multiple_coils(data)
    elseif func == 16 then
        return self:write_multiple_registers(data)
    else
        return self:exception(func, 1) -- 非法功能码
    end
end

---Modbus从站
-- @module modbus_slave
local ModbusSlave = {}
ModbusSlave.__index = ModbusSlave

protocols.register("modbus_slave", ModbusSlave)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Slave
function ModbusSlave:new(link, opts)
    local slave = setmetatable({}, self)
    slave.link = link
    slave.timeout = opts.timeout or 1000 -- 1秒钟
    slave.tcp = opts.tcp or false -- modbus tcp
    return slave
end

---打开主站
function ModbusSlave:open()
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
        local dev = ModbusSlaveDevice:new(d, self)
        dev:open() -- 设备也要打开

        self.devices[d.slave] = dev

        devices.register(d.id, dev)
    end

    -- 开启轮询
    iot.start(ModbusSlave.process, self)
end

--- 轮询
function ModbusSlave:process()
    -- 解析数据
    while self.opened do
        self.link:wait()
        local ret, data = self.link:read()

        local tid, pid, ln

        if self.tcp then
            _, tid, pid, ln = iot.unpack(data, "3>H")
            data = data:sub(7)
        end

        -- TODO 如果长度不足，则等待内容

        local slave = string.byte(data, 1)

        -- 找到设备
        local dev = self.devices[slave]
        if dev then
            local resp = dev:process(data)
            if resp and #resp > 0 then
                if self.tcp then
                    -- 拼接头，删除尾crc16
                    resp = iot.pack("3>H", tid, pid, #resp - 2) .. resp:sub(1, #resp - 2)
                end

                self.link:write(resp)
            end
        end
    end
end

--- 关闭
function ModbusSlave:close()
    self.opened = false
    self.devices = {}
    -- TODO 取消注册设备
end
