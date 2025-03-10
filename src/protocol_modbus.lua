local tag = "modbus"

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

-- 读取数据
function Modbus:read(slave, code, addr, len)
    -- local data = (string.format("%02x",slave)..string.format("%02x",code)..string.format("%04x",offset)..string.format("%04x",length)):fromHex()
    local data = pack.pack("b2>H2", slave, code, addr, len)
    local crc = pack.pack('<h', crypto.crc16_modbus(data))
    local ret = self.link:write(data .. crc)
    if not ret then return false end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    local len = 5 --应该的包长
    repeat
        --TODO 是不是每次都要等待
        ret = self.link:wait(self.timeout)
        if not ret then
            log.info(tag, "read timeout")
            return false
        end

        local r, d = self.link:read()
        if not r then return false end
        buf = buf .. d

        if #buf > 3 then
            -- 取错误码
            if string.byte(buf, 2) > 0x80 then
                return false
            end
            --第一个字节为返回的字节数
            len = 5 + string.byte(buf, 3) --重复转化了。。
        end
    until #buf >= len

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

    local ret = self.link:write(data .. crc)
    if not ret then return false end
    ret = self.link:wait(self.timeout)
    if not ret then
        log.info(tag, "write timeout")
        return false
    end

    local r, d = self.link:read()
    if not r then return false end

    -- 判断成功与否
    if string.byte(d, 2) > 0x80 then
        return false
    end

    return true
end










return Modbus
