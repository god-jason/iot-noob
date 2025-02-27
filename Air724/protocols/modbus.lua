--- 模块功能：ModbusRTU协议支持
-- @module modbus
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30
module(..., package.seeall)

local MOD = "MODBUS"

Modbus = {}

function create(link, args)
    local obj = args or {}
    setmetatable(obj, Modbus)
    self.__index = Modbus
    obj.link = link
    obj.timeout = obj.timeout or 500
    return obj
end

-- 读指令 code 1 2 3 4
function Modbus:read(slave, code, addr, len)
    local data = pack.pack("b2>H2", slave, code, addr, len)
    local crc = pack.pack('<H', crypto.crc16("MODBUS", data))
    local msg = data .. crc
    self.link.write(msg)
    local ret = self.link.read(self.timeout)
    if ret == "" or ret == nil then return false end

    --判断接收的长度，解决拆包问题
    local _, _, _, n = pack.unpack("b3")
    while #ret < n+5 do
        local r = self.link.read(self.timeout)
        if r == "" or r == nil then return false end
        ret = ret .. r
    end

    -- 删掉：从站，功能码，字数 (以及最后的校验位？)
    return string.sub(ret, 4)
    -- return unpack(string.sub(ret, 4), points)
end

-- 写指令，1->5 3->6
function Modbus:write(slave, code, addr, data)
    if code == 1 then
        code = 5
        if data then
            data = 0xFF00
        else
            data = 0x0000
        end
    elseif code == 3 then
        if #data > 2 then
            code = 16 -- 写多个寄存器
        else
            code = 6 -- 写单个寄存器
        end
    end

    local data = pack.pack("b2>H", slave, code, addr) .. data
    local crc = pack.pack('<H', crypto.crc16("MODBUS", data))
    self.link.write(msg)
    local ret = self.link.read(self.timeout)
    if ret == "" or ret == nil then return false end
    -- 判断成功与否
    local _, s, c = pack.unpack(ret, "b2")
    if c > 0x80 then
        log.info(MOD, "error") --TODO 错误码
        return false
    end
    return true
end

--轮询接口
function Modbus:poll(device, mapper)
    local data =
        self.read(device.slave, mapper.code, mapper.addr, mapper.size)
    if not data then return false end
    return parse(mapper.code, data, mapper.points)
end

--写入变量
function Modbus:put(device, name, value, mappers)
    local ret, code, addr, data = lookup(name, value, mappers)
    if not ret then return false end
    return self.write(device.slave, code, addr, data)
end

-- 数据类型
local unpackTypes = {
    --    bit = '',
    float = 'f',
    double = 'd',
    -- local NUMBER = 'n'
    int8 = 'c',
    uint8 = 'b',
    int16 = 'h',
    uint16 = 'H',
    int32 = 'i',
    uint32 = 'I',
    int64 = 'l',
    uint64 = 'L'
}

-- 解析数据
function parse(code, data, points)
    local result = {}
    if code == 1 or code == 2 then
        -- 取线圈或触点
        for i, m in ipairs(points) do
            local str = string.sub(data, m.offset / 8)
            local val = pack.unpack(str, "b")
            local pos = m.offset % 8
            result[m.name] = bit.isset(val, pos)
        end
    elseif code == 3 or code == 4 then
        -- 取寄存器
        for i, m in ipairs(points) do
            -- {offset = 0, be = true, type = "uint16", name = "temp", rate = 0.1， adjust = 0}
            local str = string.sub(data, m.offset * 2)
            -- 拼接格式
            local fmt = (m.be and '>' or '<') .. unpackTypes[m.type]
            local _, v = pack.unpack(str, fmt)
            -- 倍率
            if m.rate ~= 0 and m.rate ~= 1 then v = v * m.rate end
            -- 校准
            if m.adjust ~= 0 then v = v + m.adjust end

            result[m.name] = v
        end
    else
        log.info(MOD, "unpack unsupport code")
        ---
    end

    return result
end

-- 定位数据 
function lookup(name, value, mappers)
    for i, m in ipairs(mappers) do
        if m.code == 1 then
            -- 写线圈
            for i, p in ipairs(m.points) do
                if p.name == name then
                    return true, m.code, m.addr + p.offset, value
                end
            end
        elseif m.code == 3 then
            -- 写寄存器
            for i, p in ipairs(m.points) do
                if p.name == name then
                    -- if m.adjust ~= 0 then value = value - m.adjust end
                    if p.rate ~= 0 and p.rate ~= 1 then
                        value = value / p.rate
                    end
                    local fmt = (p.be and '>' or '<') .. unpackTypes[p.type]
                    return true, m.code, m.addr + p.offset,
                           pack.pack(fmt, value)
                end
            end
        end
    end
    return false
end
