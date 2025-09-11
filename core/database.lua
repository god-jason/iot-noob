--- 内存数据库
--- @module "database"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.09.11
local tag = "database"

local database = {}

--- 读取数据
--- @param col string 表
--- @return table 数据 {k->v}
local function load(col)
    local data = io.readFile(col .. ".db")
    local obj, result, err = json.decode(data)
    if result == 0 then
        return {}
    else
        return obj
    end
end

--- 保存数据
--- @param col string 表
--- @param objs table 数据{k->v}
local function save(col, objs)
    local data = json.encode(objs)
    return io.writeFile(col .. ".db", data)
end

--- 清空表
--- @param col string 表
function database.clear(col)
    os.remove(col .. ".db")
end

--- 插入数据
--- @param col string 表
--- @param id string ID
--- @param obj table 数据
function database.insert(col, id, obj)
    local tab = load(col)
    tab[id] = obj
    save(col, tab)
end

--- 修改数据（目前与insert相同）
--- @param col string 表
--- @param id string ID
--- @param obj table 数据
function database.update(col, id, obj)
    local tab = load(col)
    tab[id] = obj
    save(col, tab)
end

--- 插入多条
--- @param col string 表
--- @param objs table 数据
function database.insertMany(col, objs)
    local tab = load(col)
    for id, obj in pairs(objs) do
        tab[id] = obj
    end
    save(col, tab)
end

--- 插入多条
--- @param col string 表
--- @param objs table 数据
function database.insertArray(col, objs)
    local tab = load(col)
    for obj in ipairs(objs) do
        local id = objs["id"]
        tab[id] = obj
    end
    save(col, tab)
end

--- 删除
--- @param col string 表
--- @param id string ID
function database.delete(col, id)
    local tab = load(col)
    if tab ~= nil then
        table.remove(tab, id)
        save(col, tab)
    end
end

--- 获取数据
--- @param col string 表
--- @param id string ID
--- @return table 数据
function database.get(col, id)
    local tab = load(col)
    if tab ~= nil then
        return tab[id]
    end
end

--- 查询数据库
--- @param col string 表
--- @param key string 键
--- @param value any 值
--- @return table 数组
function database.find(col, ...)
    local tab = load(col)

    local results = {}

    local args = {...}

    -- 复制所有数据出来
    if #args == 0 then
        for i, v in pairs(tab) do
            table.insert(results, v)
        end
        return
    end

    -- 生成过滤条件
    local filter = {}
    for i = 1, #args, 2 do
        filter[args[i]] = args[i + 1]
    end

    -- 遍历所有数据（此处不用在意性能，因为网关一般不会存太多数据）
    for id, obj in pairs(tab) do
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

return database
