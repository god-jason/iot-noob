--- 键值数据库
-- @module kv
local kv = {}

local cache = nil

local tag = "kv"
local filename = "/kv.json"


--- 读取数据
-- @return table 数据 {k->v}
local function load()
    log.info(tag, "load")
    local ret, data = iot.readFile(filename)
    if not ret then
        cache = {}
        return
    end
    local obj, err = iot.json_decode(data)
    if err then
        log.error(tag, err)
    end
    cache = obj or {}
end

--- 保存数据
local function save()
    log.info(tag, "save")
    local data = iot.json_encode(cache)
    return iot.writeFile(filename, data)
end

local function check()
    if cache == nil then
        load()
    end
end

--- 清空表
function kv.clear()
    cache = {}
    os.remove(filename)
end

--- 写入值
-- @param key string
-- @param data any
function kv.set(key, data)
    check()
    cache[key] = data
    save()
end

--- 读取值
-- @param key string
-- @return any
function kv.get(key)
    check()
    return cache[key]
end


return kv
