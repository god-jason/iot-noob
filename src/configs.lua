local tag = "configs"

local configs = {}

---加载配置文件，自动解析json
---@param name string 文件名，不带.json后缀
---@return boolean 成功与否
---@return table|nil
function configs.load(name)
    -- 找文件
    local path = "/" .. name .. ".json"
    -- if SD.enable then
    --     path = "/sd" .. path
    -- end

    -- 找不到，则下载
    if not io.exists(path) then return false end

    -- 限制文件大小（780EPM已经到1MB了，不太需要）
    -- local size = io.fileSize(path)
    -- if size > 20000 then
    --     log.info(tag, "too large", path, size)
    --     return false
    -- end

    local data = io.readFile(path)
    local obj, ret, err = json.decode(data)
    if ret == 1 then
        return true, obj
    else
        log.info(tag, "decode failed", path, err, data)
        return false, err
    end
end

---保存配置文件，自动编码json
---@param name string 文件名，不带.json后缀
---@param data table|string 内容
---@return boolean 成功与否
function configs.save(name, data)
    if type(data) ~= "string" then
        data = json.encode(data)
    end

    -- 找文件
    local path = "/" .. name .. ".json"
    -- if SD.enable then
    --     path = "/sd" .. path
    -- end

    -- 删除历史(到底需不需要)，另外，是否需要备份
    if io.exists(path) then
        os.remove(path)
    end

    return io.writeFile(path, data)
end

return configs
