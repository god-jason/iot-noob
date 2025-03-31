--- 点位相关
--- @module "points"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "points"
local points = {}

-- 数据点类型
local feagures = {
    bool = {
        byte = 1,
        word = 1,
        pack = "b"
    },
    boolean = {
        byte = 1,
        word = 1,
        pack = "b"
    }, -- 按位去读
    char = {
        byte = 1,
        word = 1,
        pack = "c"
    },
    byte = {
        byte = 1,
        word = 1,
        pack = "b"
    },
    int8 = {
        byte = 1,
        word = 1,
        pack = "c"
    },
    uint8 = {
        byte = 1,
        word = 1,
        pack = "b"
    },
    short = {
        byte = 2,
        word = 1,
        pack = "h"
    },
    word = {
        byte = 2,
        word = 1,
        pack = "H"
    },
    int16 = {
        byte = 2,
        word = 1,
        pack = "h"
    },
    uint16 = {
        byte = 2,
        word = 1,
        pack = "H"
    },
    qword = {
        byte = 4,
        word = 2,
        pack = "I"
    },
    int = {
        byte = 4,
        word = 2,
        pack = "i"
    },
    uint = {
        byte = 4,
        word = 2,
        pack = "I"
    },
    int32 = {
        byte = 4,
        word = 2,
        pack = "i"
    },
    uint32 = {
        byte = 4,
        word = 2,
        pack = "I"
    },
    float = {
        byte = 4,
        word = 2,
        pack = "f"
    },
    float32 = {
        byte = 4,
        word = 2,
        pack = "f"
    },
    double = {
        byte = 8,
        word = 4,
        pack = "d"
    },
    float64 = {
        byte = 8,
        word = 4,
        pack = "d"
    }
}

---点位信息
---@param type string 点位类型
---@return table
function points.feagure(type)
    return feagures[type]
end

---解析位数据
---@param point table 点位信息
---@param data string 数据
---@param address integer 数据地址
---@return boolean
---@return any
function points.parseBit(point, data, address)
    --log.info(tag, "parseBit", point, #data, address)
    local offset = point.address - address
    local cursor = math.floor(offset / 8) + 1
    if #data <= cursor then
        log.info(tag, "parseBit over index")
        return false
    end
    local byte = string.byte(data, cursor)
    local value = bit.isSet(byte, offset % 8 + 1)
    return true, value
end

---解析字数据
---@param point table 点位信息
---@param data string 数据
---@param address integer 数据地址
---@return boolean
---@return any
function points.parseWord(point, data, address)
    --log.info(tag, "parseWord", point.name, point.address, #data, address)
    local feagure = feagures[point.type]
    if not feagure then
        log.info(tag, "parseWord unkown type", point.type)
        return false
    end

    local cursor = (point.address - address) * 2 + 1 -- lua索引从1开始...
    if #data <= cursor then
        log.info(tag, "parseWord over index")
        return false
    end

    -- 解码数据
    local be = point.be and ">" or "<"
    local pk = feagure.pack
    local buf = string.sub(data, cursor)
    local _, value = pack.unpack(buf, be .. pk)

    -- 倍率
    if point.rate ~= nil and point.rate ~= 0 and point.rate ~= 1 then
        value = value * point.rate
    end
    -- 校准
    if point.correct ~= nil and point.correct ~= 0 then
        value = value + point.correct
    end

    return true, value
end

---解析数据
---@param point table 点位信息
---@param data string 数据
---@param address integer 数据地址
---@return boolean
---@return any
function points.parse(point, data, address)
    local feagure = feagures[point.type]
    if not feagure then
        log.info(tag, "parse unkown type", point.type)
        return false
    end

    local cursor = point.address - address + 1 -- lua索引从1开始...
    if #data <= cursor then
        log.info(tag, "parse over index")
        return false
    end

    -- 解码数据
    local be = point.be and ">" or "<"
    local pk = feagure.pack
    local buf = string.sub(data, cursor)
    local _, value = pack.unpack(buf, be .. pk)

    -- 倍率
    if point.rate ~= nil and point.rate ~= 0 and point.rate ~= 1 then
        value = value * point.rate
    end
    -- 校准
    if point.correct ~= nil and point.correct ~= 0 then
        value = value + point.correct
    end

    return true, value
end

---编码数据
---@param point table 点位信息
---@param value any 数据
---@return boolean 成功与否
---@return string|nil
function points.encode(point, value)
    local feagure = feagures[point.type]
    if not feagure then
        log.info(tag, "encode unkown type", point.type)
        return false
    end

    -- 校准
    if point.correct ~= nil and point.correct ~= 0 then
        value = value - point.correct
    end

    -- 倍率
    if point.rate ~= nil and point.rate ~= 0 and point.rate ~= 1 then
        value = value / point.rate
    end

    local be = point.be and ">" or "<"
    local pk = feagure.pack
    local data = pack.pack(be .. pk, value)
    return true, data
end

return points
