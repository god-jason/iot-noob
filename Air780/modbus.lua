local tag = "MODBUS"

Modbus = {}


function Modbus:new(link, timeout)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.link = link
    obj.timeout = timeout or 1000
    return obj
end

-- 读取数据
function Modbus:read(slave, code, addr, len)    
    -- local data = (string.format("%02x",slave)..string.format("%02x",code)..string.format("%04x",offset)..string.format("%04x",length)):fromHex()
    local data = pack.pack("b2>H2", slave, code, addr, len)
    local crc = pack.pack('<h', crypto.crc16("MODBUS",data))
    self.link.write(data..crc)
    local ret = self.link.read(2000)
    if ret == "" or ret == nil then return false end
    --TODO 解决分包问题
    
    
end

-- 写入数据
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

    self.link.write(data..crc)
    local ret = self.link.read(self.timeout)
    if ret == "" or ret == nil then return false end

    -- 判断成功与否
    local _, s, c = pack.unpack(ret, "b2")
    if c > 0x80 then
        log.info(tag, "error", c) --TODO 错误码
        return false
    end

    return true
end