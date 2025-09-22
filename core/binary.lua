--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 二进制处理库
-- @module binary
local binary = {}


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

function binary.decodeHex(str)
    if not str or #str == 0 then
        return ""
    end
    local ret = ""
    for i = 1, #str, 2 do
        local byteStr = str:sub(i, i+1)
        local byte = tonumber(byteStr, 16)
        ret = ret .. string.char(byte)
    end
    return ret
end

function binary.decodeBCD(len, str)
    if not str or #str == 0 then
        return ""
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
    local year = binary.decodeBCD(1, str:sub(1, 1)) * 100 + binary.decodeBCD(1, str:sub(2, 2))
    local month = binary.decodeBCD(1, str:sub(3, 3))
    local day = binary.decodeBCD(1, str:sub(4, 4))
    local hour = binary.decodeBCD(1, str:sub(5, 5))
    local min = binary.decodeBCD(1, str:sub(6, 6))
    local sec = binary.decodeBCD(1, str:sub(7, 7))
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
    str = str .. binary.encodeBCD(tm.year // 100, 1)
    str = str .. binary.encodeBCD(tm.year % 100, 1)
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

return binary