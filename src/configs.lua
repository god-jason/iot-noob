local tag = "configs"

local configs = {}

function configs.load(name)
    -- 找文件
    local path = "/" .. name .. ".json"
    -- if SD.enable then
    --     path = "/sd" .. path
    -- end

    -- 找不到，则下载
    if not io.exists(path) then return false end

    local size = io.fileSize(path)
    if size > 20000 then
        log.info(tag, "too large", path, size)
        return false
    end

    local data = io.readFile(path)
    local obj, ret, err = json.decode(data)
    if ret == 1 then
        return true, obj
    else
        log.info(tag, "decode failed", path, err, data)
        return false, err
    end
end

function configs.save(name, data)

    local str = json.encode(data)
    if str == nil then
        log.info(tag, "encode failed", path, err, data)
        return false
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