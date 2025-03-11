local points = {}

-- 数据点类型
points.feagure = {
    bool = { byte = 1, word = 1, pack = "b" },
    boolean = { byte = 1, word = 1, pack = "b" }, --按位去读
    char = { byte = 1, word = 1, pack = "c" },
    byte = { byte = 1, word = 1, pack = "b" },
    int8 = { byte = 1, word = 1, pack = "c" },
    uint8 = { byte = 1, word = 1, pack = "b" },
    short = { byte = 2, word = 1, pack = "h" },
    word = { byte = 2, word = 1, pack = "H" },
    int16 = { byte = 2, word = 1, pack = "h" },
    uint16 = { byte = 2, word = 1, pack = "H" },
    qword = { byte = 4, word = 2, pack = "I" },
    int = { byte = 4, word = 2, pack = "i" },
    uint = { byte = 4, word = 2, pack = "I" },
    int32 = { byte = 4, word = 2, pack = "i" },
    uint32 = { byte = 4, word = 2, pack = "I" },
    float = { byte = 4, word = 2, pack = "f" },
    float32 = { byte = 4, word = 2, pack = "f" },
    double = { byte = 8, word = 4, pack = "d" },
    float64 = { byte = 8, word = 4, pack = "d" }
}

---解析位数据
---@param point table 点位信息
---@param data string 数据
---@param address integer 数据地址
---@return any
function points.parseBit(point, data, address)
    local offset = point.address - address + 1
    local byte = string.byte(data, math.floor(offset / 8))
    local value = bit.isSet(byte, offset % 8)
    return value
end

---解析字数据
---@param point table 点位信息
---@param data string 数据
---@param address integer 数据地址
---@return any
function points.parseWord(point, data, address)
    local feagure = points.feature[point.type]
    if feagure then
        --编码数据
        local be = point.be and ">" or "<"
        local pk = feagure.pack
        local buf = string.sub(data, (point.address - address) * 2 + 1) --lua索引从1开始...
        local _, value = pack.unpack(buf, be .. pk)
        return value
    end
    return nil
end

---解析数据
---@param point table 点位信息
---@param data string 数据
---@param address integer 数据地址
---@return any
function points.parse(point, data, address)
    local feagure = points.feature[point.type]
    if feagure then
        --编码数据
        local be = point.be and ">" or "<"
        local pk = feagure.pack
        local buf = string.sub(data, point.address - address + 1) --lua索引从1开始...
        local _, value = pack.unpack(buf, be .. pk)
        return value
    end
    return nil
end

---编码数据
---@param point table 点位信息
---@param value any 数据
---@return boolean 成功与否
---@return string|nil
function points.encode(point, value)
    local feagure = points.feature[point.type]
    if not feagure then return false end
    local be = point.be and ">" or "<"
    local pk = feagure.pack
    data = pack.pack(be .. pk, value)
    return true, data
end

return points
