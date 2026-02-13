--- 配置文件相关
-- @module configs
local configs = {}

local tag = "configs"

-- local utils = require("utils")

local function luadb_config(name)
    -- 带后缀名，长度不能大于31
    return "/luadb/" .. string.gsub(name, "/", "-") .. ".json"
end

---加载配置文件，自动解析json
-- @param name string 文件名，不带.json后缀
-- @return boolean 成功与否
-- @return table|nil
-- @return string 最终文件名
function configs.load(name)
    log.info(tag, "load", name)

    -- 1、找原始JSON文件hen
    local path = "/" .. name .. ".json"
    -- 2、从luadb中找，（编译时添加）文件名长度限制在31字节。。。
    local path2 = luadb_config(name) 

    -- 降低启动速度，避免日志输出太快，从而导致丢失
    -- iot.sleep(100)

    if iot.exists(path) then
        -- do nothing 找到了未压缩的文件
        log.info(tag, "found", path)
    elseif iot.exists(path2) then
        path = path2
    else
        -- log.info(tag, name, "not found")
        return false
    end

    -- 限制文件大小（780EPM已经到1MB了，不太需要）
    -- local size = io.fileSize(path)
    -- if size > 20000 then
    --     log.info(tag, "too large", path, size)
    --     return false
    -- end

    local ret, data = iot.readFile(path)
    if not ret then
        return false, "文件打开失败"
    end
    -- log.info(tag, "from", path, #data)

    local obj, err = iot.json_decode(data)
    if err then
        log.error(tag, "decode failed", path, err, data)
        return false, err
    else
        return true, obj, path
    end
end

---加载配置文件，如果不存在，则用默认
-- @param name string 文件名，不带.json后缀
-- @param default table 默认内容
-- @return table
function configs.load_default(name, default)
    -- log.info(tag, "load", name)
    local ret, data = configs.load(name)
    if not ret then
        return default
    end
    return data
end

---保存配置文件，自动编码json
-- @param name string 文件名，不带.json后缀
-- @param data table|string 内容
-- @return boolean 成功与否
-- @return string 最终文件名
function configs.save(name, data)
    log.info(tag, "save", name, data)

    if type(data) ~= "string" then
        data = iot.json_encode(data)
    end

    -- 创建父目录
    local ss = string.split(name, "/")
    if #ss > 1 then
        local dir = "/"
        for i = 1, #ss - 1, 1 do
            dir = dir .. "/" .. ss[i]
            iot.mkdir(dir)
            -- log.info(tag, "mkdir", dir, r, e)
        end
    end

    -- 找文件
    local path = "/" .. name .. ".json"

    os.remove(path)

    -- 删除历史(到底需不需要)，另外，是否需要备份
    -- if io.exists(path) then
    --     os.remove(path)
    -- end

    return iot.writeFile(path, data)
end

---删除配置文件
-- @param name string 文件名，不带.json后缀
function configs.delete(name)
    log.info(tag, "delete", name)

    -- 找文件
    local path = "/" .. name .. ".json"
    os.remove(path)

    -- 删除目录
    -- utils.remove_all(name)
end

return configs
