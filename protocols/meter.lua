local meter = {}

local binary = require("binary")

-- 数据格式
local types = {
    ["XXXXXXXX"] = {
        type = "bcd",
        size = 4
    },
    ["XXXXXX"] = {
        type = "bcd",
        size = 3
    },
    ["XXXXXX.XX"] = {
        type = "bcd",
        size = 4,
        rate = 0.01
    },
    ["XXXX"] = {
        type = "bcd",
        size = 2
    },
    ["XXXX.XX"] = {
        type = "bcd",
        size = 3,
        rate = 0.01
    },
    ["XXXX.XXXX"] = {
        type = "bcd",
        size = 4,
        rate = 0.0001
    },
    ["XXX.X"] = {
        type = "bcd",
        size = 2,
        rate = 0.1
    },
    ["XXX.XXX"] = {
        type = "bcd",
        size = 3,
        rate = 0.001
    },
    ["XX"] = {
        type = "bcd",
        size = 1
    },
    ["XX.XX"] = {
        type = "bcd",
        size = 2,
        rate = 0.01
    },
    ["XX.XXXX"] = {
        type = "bcd",
        size = 3,
        rate = 0.0001
    },
    ["X.XXX"] = {
        type = "bcd",
        size = 2,
        rate = 0.001
    },
    ["HH"] = {
        type = "hex",
        size = 1
    },
    ["HHHH"] = {
        type = "hex",
        size = 2
    },
    ["YYYYMMDDhhmmss"] = {
        type = "datetime",
        size = 7
    },
    ["YYMMDDhhmmss"] = {
        type = "datetime6",
        size = 6
    },
    ["YYMMDDhhmm"] = {
        type = "datetime5",
        size = 5
    },
    ["YYYYMMDD"] = {
        type = "date",
        size = 4
    },
    ["uint8"] = {
        type = "u8",
        size = 1
    },
    ["uint16"] = {
        type = "u16",
        size = 2
    }
}

function meter.decode(data, type, reverse)
    local fmt = types[type]
    if not fmt then
        return false, "未知数据类型" .. type
    end

    if #data < fmt.size then
        return false, "数据长度不足"
    end

    local str = data:sub(1, fmt.size)
    if reverse == true and fmt.size > 1 then
        str = string.reverse(str)
    end

    local value
    if fmt.type == "bcd" then
        value = binary.decodeBCD(fmt.size, str)
        if fmt.rate then
            value = value * fmt.rate
        end
    elseif fmt.type == "hex" then
        value = 0
        for i = 1, fmt.size do
            value = (value << 8) | str:byte(i)
        end
    elseif fmt.type == "date" then
        value = binary.encodeHex(str) -- 字符串 YYYYMMDD
    elseif fmt.type == "datetime" then
        value = binary.encodeHex(str) -- 字符串 YYYYMMDDhhmmss
    elseif fmt.type == "datetime6" then
        value = "20" .. binary.encodeHex(str) -- 字符串
    elseif fmt.type == "datetime5" then
        value = "20" .. binary.encodeHex(str) .. "00" -- 字符串
    elseif fmt.type == "u8" then
        value = str:byte(1)
    elseif fmt.type == "u16" then
        value = str:byte(1) | (str:byte(2) << 8)
    else
        return false, "不支持的数据格式"
    end
    return true, value, fmt.size
end

function meter.encode(type, value)
    return false, "暂不支持编码数据"
end

return meter
