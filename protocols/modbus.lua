--- Modbus 协议基础库
-- @module modbus
local modbus = {}

local log = iot.logger("modbus")

local points = require("points")
local binary = require("binary")
local model = require("model")

--- Modbus CRC16
-- @param data string
-- @return integer crc
function modbus.crc16(data)
    local crc = 0xFFFF
    for i = 1, #data do
        crc = crc ~ string.byte(data, i)
        for _ = 1, 8 do
            if (crc & 1) ~= 0 then
                crc = (crc >> 1) ~ 0xA001
            else
                crc = crc >> 1
            end
        end
    end
    return crc
end

--- Modbus CRC16
-- @param data string
-- @return string crc
function modbus.crc16_bytes(data)
    local crc = modbus.crc16(data)
    local lo = crc & 0xFF
    local hi = (crc >> 8) & 0xFF
    return string.char(lo, hi)
end

local function normalize_address(addr)
    if type(addr) == "string" then
        if addr:startsWith("H") or addr:startsWith("h") then
            local buf = binary.decodeHex(addr:sub(2))
            local num = 0
            for i = 1, #buf do
                num = num << 8
                num = num + string.byte(buf, i)
            end
            addr = num
        else
            addr = tonumber(addr)
        end
    end
    return addr
end

local mapper_cache = {}

-- 升序排列
local function sortPoint(pt1, pt2)
    return pt1.address < pt2.address
end

---Modbus地址表
-- @module ModbusMapper
local ModbusMapper = {}
ModbusMapper.__index = ModbusMapper

function ModbusMapper:new(product_id)
    return setmetatable({
        product_id = product_id,

        -- 按类型分类
        coils = {},
        discrete_inputs = {},
        holding_registers = {},
        input_registers = {},

        -- 索引
        coils_index = {},
        discrete_inputs_index = {},
        holding_registers_index = {},
        input_registers_index = {},

        -- 轮询器
        pollers = {}
    }, ModbusMapper)
end


function ModbusMapper:load()
    log.info("load", self.product_id)
    local mod = model.get(self.product_id)
    if not mod then
        return false, "加载产品物模型失败" .. self.product_id
    end

    self.model = mod

    log.info("load 2")

    -- 分类
    for _, prop in ipairs(mod.content or {}) do
        for _, pt in ipairs(prop.points) do
            if pt.register == 1 then
                table.insert(self.coils, pt)
            elseif pt.register == 2 then
                table.insert(self.discrete_inputs, pt)
            elseif pt.register == 3 then
                table.insert(self.holding_registers, pt)
            elseif pt.register == 4 then
                table.insert(self.input_registers, pt)
            end
        end
    end

    -- 兼容字符串地址
    for i, p in ipairs(self.coils) do
        p.address = normalize_address(p.address)
        self.coils_index[p.name] = p
    end
    for i, p in ipairs(self.discrete_inputs) do
        p.address = normalize_address(p.address)
        self.discrete_inputs_index[p.name] = p
    end
    for i, p in ipairs(self.holding_registers) do
        p.address = normalize_address(p.address)
        self.holding_registers_index[p.name] = p
    end
    for i, p in ipairs(self.input_registers) do
        p.address = normalize_address(p.address)
        self.input_registers_index[p.name] = p
    end

    -- 排序
    table.sort(self.coils, sortPoint)
    table.sort(self.discrete_inputs, sortPoint)
    table.sort(self.holding_registers, sortPoint)
    table.sort(self.input_registers, sortPoint)

    --log.info("before pollers", iot.json_encode(self.coils))

    -- 间隔3个以内，视为连续地址
    local sep = 3

    -- 自计算轮询器
    if #(self.coils) > 0 then
        local begin = self.coils[1]
        local last = begin
        for i = 2, #(self.coils), 1 do
            if self.coils[i].address > last.address + 1 + sep then
                table.insert(self.pollers, {
                    register = 1,
                    address = begin.address,
                    length = last.address - begin.address + 1
                })
                begin = self.coils[i]
            end
            last = self.coils[i]
        end
        table.insert(self.pollers, {
            register = 1,
            address = begin.address,
            length = last.address - begin.address + 1
        })
    end
    if #(self.discrete_inputs) > 0 then
        local begin = self.discrete_inputs[1]
        local last = begin
        for i = 2, #(self.discrete_inputs), 1 do
            if self.discrete_inputs[i].address > last.address + 1 + sep then
                table.insert(self.pollers, {
                    register = 2,
                    address = begin.address,
                    length = last.address - begin.address + 1
                })
                begin = self.discrete_inputs[i]
            end
            last = self.discrete_inputs[i]
        end
        table.insert(self.pollers, {
            register = 2,
            address = begin.address,
            length = last.address - begin.address + 1
        })
    end
    if #(self.holding_registers) > 0 then
        local begin = self.holding_registers[1]
        local last = begin
        for i = 2, #(self.holding_registers), 1 do

            local feature = points.feature(last.type)
            if feature then
                if self.holding_registers[i].address > last.address + feature.word + sep * 2 then
                    table.insert(self.pollers, {
                        register = 3,
                        address = begin.address,
                        length = last.address - begin.address + feature.word
                    })
                    begin = self.holding_registers[i]
                end
            end

            last = self.holding_registers[i]
        end

        local feature = points.feature(last.type)
        if feature then
            table.insert(self.pollers, {
                register = 3,
                address = begin.address,
                length = last.address - begin.address + feature.word
            })
        end
    end
    if #(self.input_registers) > 0 then
        local begin = self.input_registers[1]
        local last = begin
        for i = 2, #(self.input_registers), 1 do

            local feature = points.feature(last.type)
            if feature then
                if self.input_registers[i].address > last.address + feature.word + sep * 2 then
                    table.insert(self.pollers, {
                        register = 4,
                        address = begin.address,
                        length = last.address - begin.address + feature.word
                    })
                    begin = self.input_registers[i]
                end
            end

            last = self.input_registers[i]
        end

        local feature = points.feature(last.type)
        if feature then
            table.insert(self.pollers, {
                register = 4,
                address = begin.address,
                length = last.address - begin.address + feature.word
            })
        end
    end

    log.info("pollers", iot.json_encode(self.pollers))

    -- 保存至缓存
    mapper_cache[self.product_id] = self

    return true
end

-- 查找点位，读
function ModbusMapper:find(key)
    local pt = self.coils_index[key]
    if pt then
        return pt
    end
    pt = self.discrete_inputs_index[key]
    if pt then
        return pt
    end
    pt = self.holding_registers_index[key]
    if pt then
        return pt
    end
    pt = self.input_registers_index[key]
    if pt then
        return pt
    end
    return nil
end

-- 查找点位，写
function ModbusMapper:find_write(key)
    local pt = self.coils_index[key]
    if pt and pt.mode ~= "r" then
        return pt
    end
    pt = self.discrete_inputs_index[key]
    if pt and pt.mode ~= "r" then
        return pt
    end
    pt = self.holding_registers_index[key]
    if pt and pt.mode ~= "r" then
        return pt
    end
    pt = self.input_registers_index[key]
    if pt and pt.mode ~= "r" then
        return pt
    end
    return nil
end

function ModbusMapper:parse(data, register, address, length)
    local has = false
    local values = {}

    if register == 1 then
        log.info("parse 1 ", #data)
        for _, point in ipairs(self.coils) do
            if address <= point.address and point.address < address + length then
                local r, v = points.parseBit(point, data, address)
                if r then
                    -- self:put_value(point.name, v)
                    has = true
                    if point.name and #point.name > 0 then
                        values[point.name] = v    
                    end
                end
            end
        end
        log.info("parse 1 ", iot.json_encode(values))
    elseif register == 2 then
        log.info("parse 2 ", #data)
        for _, point in ipairs(self.discrete_inputs) do
            if address <= point.address and point.address < address + length then
                local r, v = points.parseBit(point, data, address)
                if r then
                    -- self:put_value(point.name, v)
                    has = true
                    if point.name and #point.name > 0 then
                        values[point.name] = v    
                    end
                end
            end
        end
        log.info("parse 2 ", iot.json_encode(values))
    elseif register == 3 then
        log.info("parse 3 ", #data)
        for _, point in ipairs(self.holding_registers) do
            if address <= point.address and point.address < address + length then
                local r, v = points.parseWord(point, data, address)
                if r then
                    if point.bits ~= nil and #point.bits > 0 then
                        for _, b in ipairs(point.bits) do
                            local vv = (0x01 << b.bit) & v > 0
                            -- self:put_value(point.name, vv)
                            has = true
                            if b.name and #b.name > 0 then
                                values[b.name] = vv    
                            end
                        end
                    else
                        -- self:put_value(point.name, v)
                        has = true
                        if point.name and #point.name > 0 then
                            values[point.name] = v    
                        end
                    end
                end
            end
        end
        log.info("parse 3 ", iot.json_encode(values))
    elseif register == 4 then
        log.info("parse 4 ", #data)
        for _, point in ipairs(self.input_registers) do
            if address <= point.address and point.address < address + length then
                local r, v = points.parseWord(point, data, address)
                if r then
                    if point.bits ~= nil and #point.bits > 0 then
                        for _, b in ipairs(point.bits) do
                            local vv = (0x01 << b.bit) & v > 0
                            -- self:put_value(point.name, vv)
                            has = true
                            if b.name and #b.name > 0 then
                                values[b.name] = vv    
                            end
                        end
                    else
                        -- self:put_value(point.name, v)
                        has = true
                        if point.name and #point.name > 0 then
                            values[point.name] = v    
                        end
                    end
                end
            end
        end
        log.info("parse 4 ", iot.json_encode(values))
    else
        -- 暂不支持其他类型
    end

    return has, values
end


-- 加载地址映射
function modbus.load_mapper(product_id)
    if mapper_cache[product_id] then
        return mapper_cache[product_id]
    end

    local mapper = ModbusMapper:new(product_id)
    mapper_cache[product_id] = mapper

    local ret, info = mapper:load()
    if not ret then
        log.error(info)
        iot.emit("error", "modbus解析地址表错误：" .. (info or ""))
    end

    return mapper
end

return modbus
