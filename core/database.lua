--- 文件数据库
-- @module database
local database = {}

local tag = "database"

-- 统一文件名
local function dbname(col)
    return "/db-" .. col .. ".json"
end

--- 读取数据
-- @param col string 表
-- @return table 数据 {k->v}
function database.load(col)
    log.info(tag, "load", col)
    local name = dbname(col)
    if not iot.exists(name) then
        name = "/luadb" .. name
    end
    local ret, data = iot.readFile(name)
    if not ret then
        return {}
    end
    local obj, err = iot.json_decode(data)
    if err then
        log.error(tag, err)
        return {}
    else
        return obj
    end
end

--- 保存数据
-- @param col string 表
-- @param objs table 数据{k->v}
function database.save(col, objs)
    log.info(tag, "save", col)
    local data, err = iot.json_encode(objs)
    if data == nil then
        log.error(tag, err)
        return false
    end
    return iot.writeFile(dbname(col), data)
end

--- 清空表
-- @param col string 表
function database.clear(col)
    --local ret, err = os.remove(dbname(col))
    return database.save(col, {})
end

--- 插入数据
-- @param col string 表
-- @param id string ID
-- @param obj table 数据
function database.insert(col, id, obj)
    local tab = database.load(col)
    tab[tostring(id)] = obj
    database.save(col, tab)
end

--- 修改数据（目前与insert相同）
-- @param col string 表
-- @param id string ID
-- @param obj table 数据
function database.update(col, id, obj)
    local tab = database.load(col)
    tab[tostring(id)] = obj
    database.save(col, tab)
end

--- 插入多条
-- @param col string 表
-- @param objs table 数据
function database.insertMany(col, objs)
    local tab = database.load(col)
    for id, obj in pairs(objs) do
        tab[id] = obj
    end
    database.save(col, tab)
end

--- 插入多条
-- @param col string 表
-- @param objs table 数据
function database.insertArray(col, objs)
    local tab = database.load(col)
    for i, obj in ipairs(objs) do
        local id = obj["id"]
        tab[tostring(id)] = obj
    end
    database.save(col, tab)
end

--- 删除
-- @param col string 表
-- @param id string ID
function database.delete(col, id)
    local tab = database.load(col)
    if tab ~= nil then
        table.remove(tab, tostring(id))
        database.save(col, tab)
    end
end

--- 获取数据
-- @param col string 表
-- @param id string ID
-- @return table 数据
function database.get(col, id)
    local tab = database.load(col)
    if tab ~= nil then
        return tab[tostring(id)]
    end
    return nil
end

--- 查询数据库
-- @param col string 表
-- @param key string 键
-- @param value any 值
-- @return table 数组
function database.find(col, ...)
    local tab = database.load(col)

    local results = {}

    local args = {...}
    log.info(tag, "find", col, unpack(args))

    -- 复制所有数据出来
    if #args == 0 then
        for _, v in pairs(tab) do
            table.insert(results, v)
        end
        return results
    end

    -- 生成过滤条件
    local filter = {}
    for i = 1, #args, 2 do
        filter[args[i]] = args[i + 1]
    end

    -- 遍历所有数据（此处不用在意性能，因为网关一般不会存太多数据）
    for _, obj in pairs(tab) do
        local ok = true
        for k, v in pairs(filter) do
            if obj[k] ~= v then
                ok = false
                break
            end
        end
        if ok then
            table.insert(results, obj)
        end
    end

    return results
end

--- 查询数据库数量
-- @param col string 表
-- @param key string 键
-- @param value any 值
-- @return integer 数量
function database.count(col, ...)
    local tab = database.load(col)

    local ret = 0

    local args = {...}
    log.info(tag, "find", col, unpack(args))

    -- 复制所有数据出来
    if #args == 0 then
        for _, v in pairs(tab) do
            ret = ret + 1
        end
        return ret
    end

    -- 生成过滤条件
    local filter = {}
    for i = 1, #args, 2 do
        filter[args[i]] = args[i + 1]
    end

    -- 遍历所有数据（此处不用在意性能，因为网关一般不会存太多数据）
    for _, obj in pairs(tab) do
        local ok = true
        for k, v in pairs(filter) do
            if obj[k] ~= v then
                ok = false
                break
            end
        end
        if ok then
            ret = ret + 1
        end
    end

    return ret
end

return database
