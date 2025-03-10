local tag = "product"
local products  = {}

local cache = {}

--- 加载产品配置
--- @param id any 产品ID
--- @param config any 配置文件
--- @return boolean 成功
--- @return table 配置内容
function products.load(id, config)
    -- 取缓存
    if cache[id] == nil then
        cache[id] = {}
    end
    if cache[id][config] ~= nil then
        return true, cache[id][config]
    end

    -- 找文件
    local path = "/product/" .. id .. "/" .. config .. ".json"
    if SD.enable then
        path = "/sd" .. path
    end

    -- 找不到，则下载
    if not io.exists(path) then
        local ret = download(id, config)
        if not ret then
            log.info(tag, "download failed", id, config)
            cache[id][config] = false --下载失败
            return false
        end
    end

    local size = io.fileSize(path)
    if size > 20000 then
        log.info(tag, "too large", path, size)
        cache[id][config] = false
        return false
    end

    local data = io.readFile(path)
    local obj, ret, err = json.decode(data)
    if ret == 1 then
        return true, obj
    else
        log.info(tag, "parse failed", path, err)
        cache[id][config] = false
        return false, err
    end
end

--- 下载产品配置
--- @param id any 产品ID
--- @param config any 配置文件
--- @return boolean 成功
function products.download(id, config)
    local dir = "/product/" .. id
    if SD.enable then
        dir = "/sd" .. dir
    end
    if not io.exists(dir) then
        io.mkdir(dir)
    end
    local path = dir .. "/" .. config .. ".json"
    os.remove(path) --先删除

    local url = "http://iot.busycloud.cn/noob/product/" .. id .. "/" .. config .. ".json"

    -- 下载文件
    local code, headers, body = http.request("GET", url).wait()
    if code == 200 then
        return io.writeFile(path, body)
    end

    return false
end

return products