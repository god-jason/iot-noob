--- 二进制处理库
-- @module binary
local binary = {}

--- 解码数据
-- @param fmt string 格式
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decode(fmt, str, le)
    if not str or #str == 0 then
        return 0
    end
    local op = le and "<" or ">"
    local _, ret = iot.unpack(str, op .. fmt)
    return ret
end

--- 编码数据
-- @param fmt string 格式
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encode(fmt, val, le)
    local op = le and "<" or ">"
    return iot.pack(op .. fmt, val)
end

--- 解码int8
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeInt8(str, le)
    return binary.decode("c", str, le)
end
--- 编码int8
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeInt8(val, le)
    return binary.encode("c", val, le)
end
--- 解码uint8
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeUint8(str, le)
    return binary.decode("b", str, le)
end
--- 编码uint8
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeUint8(val, le)
    return binary.encode("b", val, le)
end
--- 解码int16
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeInt16(str, le)
    return binary.decode("h", str, le)
end
--- 编码int16
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeInt16(val, le)
    return binary.encode("h", val, le)
end
--- 解码uint16
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeUint16(str, le)
    return binary.decode("H", str, le)
end
--- 编码uint16
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeUint16(val, le)
    return binary.encode("H", val, le)
end
--- 解码int32
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeInt32(str, le)
    return binary.decode("i", str, le)
end
--- 编码int32
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeInt32(val, le)
    return binary.encode("i", val, le)
end
--- 解码uint32
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeUint32(str, le)
    return binary.decode("I", str, le)
end
--- 编码uint32
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeUint32(val, le)
    return binary.encode("I", val, le)
end
--- 解码int64
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeInt64(str, le)
    return binary.decode("l", str, le)
end
--- 编码int64
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeInt64(val, le)
    return binary.encode("l", val, le)
end
--- 解码uint64
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeUint64(str, le)
    return binary.decode("L", str, le)
end
--- 编码uint64
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeUint64(val, le)
    return binary.encode("L", val, le)
end
--- 解码float32
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeFloat32(str, le)
    return binary.decode("f", str, le)
end
--- 编码float32
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeFloat32(val, le)
    return binary.encode("f", val, le)
end
--- 解码float64
-- @param str string 字符串
-- @param le boolean 小端（默认大端）
-- @return any
function binary.decodeFloat64(str, le)
    return binary.decode("d", str, le)
end
--- 编码float64
-- @param val any 数据
-- @param le boolean 小端（默认大端）
-- @return string
function binary.encodeFloat64(val, le)
    return binary.encode("d", val, le)
end

--- 解码HEX
-- @param str string HEX字符串
-- @return string 字符串
function binary.decodeHex(str)
    if not str or #str == 0 then
        return ""
    end
    local ret = ""
    for i = 1, #str, 2 do
        local byteStr = str:sub(i, i + 1)
        local byte = tonumber(byteStr, 16)
        ret = ret .. string.char(byte)
    end
    return ret
end

--- 编码HEX
-- @param str string 字符串
-- @return string HEX字符串
function binary.encodeHex(str)
    if not str or #str == 0 then
        return ""
    end
    local ret = ""
    for i = 1, #str do
        ret = ret .. string.format("%02X", str:byte(i))
    end
    return ret
end

--- 解码BCD
-- @param len integer 长度
-- @param str string 字符串
-- @return integer
function binary.decodeBCD(len, str)
    if not str or #str == 0 then
        return 0
    end
    local ret = 0
    for i = 1, len do
        local b = str:byte(i)
        local h = (b >> 4) & 0x0F
        local l = b & 0x0F
        ret = ret * 100 + h * 10 + l
    end
    return ret
end

--- 编码BCD
-- @param num integer 数值
-- @param str string 字符串
-- @return integer
function binary.encodeBCD(num, len)
    local str = ""
    for i = len, 1, -1 do
        local b = num % 100
        local h = (b // 10) & 0x0F
        local l = b % 10
        str = string.char((h << 4) | l) .. str
        num = num // 100
    end
    return str
end

function binary.decodeDatetimeBCD(str)
    if not str or #str == 0 then
        return 0
    end
    local year = binary.decodeBCD(2, str:sub(1, 2))
    local month = binary.decodeBCD(1, str:sub(3, 3))
    local day = binary.decodeBCD(1, str:sub(4, 4))
    local hour = binary.decodeBCD(1, str:sub(5, 5))
    local min = binary.decodeBCD(1, str:sub(6, 6))
    local sec = binary.decodeBCD(1, str:sub(7, 7))
    log.info("binary", "decodeDatetimeBCD", year, month, day, hour, min, sec)
    return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    })
end

function binary.encodeDatetimeBCD(t)
    local tm = os.date("*t", t)
    local str = ""
    str = str .. binary.encodeBCD(tm.year, 2)
    str = str .. binary.encodeBCD(tm.month, 1)
    str = str .. binary.encodeBCD(tm.day, 1)
    str = str .. binary.encodeBCD(tm.hour, 1)
    str = str .. binary.encodeBCD(tm.min, 1)
    str = str .. binary.encodeBCD(tm.sec, 1)
    return str
end

function binary.decodeShortDatetimeBCD(str)
    if not str or #str == 0 then
        return 0
    end
    local year = binary.decodeBCD(1, str:sub(1, 1)) + 2000
    local month = binary.decodeBCD(1, str:sub(2, 2))
    local day = binary.decodeBCD(1, str:sub(3, 3))
    local hour = binary.decodeBCD(1, str:sub(4, 4))
    local min = binary.decodeBCD(1, str:sub(5, 5))
    local sec = binary.decodeBCD(1, str:sub(6, 6))
    return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    })
end

function binary.encodeShortDatetimeBCD(t)
    local tm = os.date("*t", t)
    local str = ""
    str = str .. binary.encodeBCD(tm.year % 100, 1)
    str = str .. binary.encodeBCD(tm.month, 1)
    str = str .. binary.encodeBCD(tm.day, 1)
    str = str .. binary.encodeBCD(tm.hour, 1)
    str = str .. binary.encodeBCD(tm.min, 1)
    str = str .. binary.encodeBCD(tm.sec, 1)
    return str
end

--- 逆序字符串
-- @param str string 字符串
-- @return string
function binary.reverse(str)
    if not str or #str == 0 then
        return ""
    end
    local ret = ""
    for i = #str, 1, -1 do
        ret = ret .. str:sub(i, i)
    end
    return ret
end

--- 和检验
-- @param str string 字符串
-- @return integer
function binary.sum(str)
    if not str or #str == 0 then
        return 0
    end
    local ret = 0
    for i = 1, #str, 1 do
        ret = ret + str:byte(1)
    end
    return ret
end

--- 异或检验
-- @param str string 字符串
-- @return integer
function binary.xor(str)
    if not str or #str == 0 then
        return 0
    end
    local ret = 0x00 -- 默认0，有些异或检验初始为0xFF
    for i = 1, #str, 1 do
        ret = ret ^ str:byte(1)
    end
    return ret
end

return binary
