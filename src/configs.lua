--- 配置文件相关
--- @module "configs"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "configs"

local configs = {}

local utils = require("utils")

---加载配置文件，自动解析json
---@param name string 文件名，不带.json后缀
---@return boolean 成功与否
---@return table|nil
function configs.load(name)
    log.info(tag, "load", name)

    -- 找文件
    local path = "/" .. name .. ".json"
    local path2 = "/" .. name .. ".json.flz"
    local path3 = "/luadb/" .. string.gsub(name, "/", "_") .. ".json" -- 文件名长度限制在21字节。。。

    local compressed = false -- 压缩引擎

    -- 找不到原始文件，则找压缩文件
    if io.exists(path) then
        -- 找到了未压缩的文件
    elseif fastlz and io.exists(path2) then
        compressed = true
        path = path2
    elseif io.exists(path3) then
        path = path3
    else
        return false
    end

    -- 限制文件大小（780EPM已经到1MB了，不太需要）
    -- local size = io.fileSize(path)
    -- if size > 20000 then
    --     log.info(tag, "too large", path, size)
    --     return false
    -- end

    local data = io.readFile(path)

    -- 解压
    if compressed then
        data = fastlz.uncompress(data, 32 * 1024) -- 最大32KB
    end

    local obj, ret, err = json.decode(data)
    if ret == 1 then
        return true, obj
    else
        log.info(tag, "decode failed", path, err, data)
        return false, err
    end
end

---加载配置文件，如果不存在，则用默认
---@param name string 文件名，不带.json后缀
---@param default table 默认内容
---@return table
function configs.load_default(name, default)
    -- log.info(tag, "load", name)
    local ret, data = configs.load(name)
    if not ret then
        return default
    end
    return data
end

---保存配置文件，自动编码json
---@param name string 文件名，不带.json后缀
---@param data table|string 内容
---@return boolean 成功与否
function configs.save(name, data)
    log.info(tag, "save", name, data)

    if type(data) ~= "string" then
        data = json.encode(data)
    end

    -- 创建父目录
    local ss = string.split(name, "/")
    if #ss > 1 then
        local dir = "/"
        for i = 1, #ss - 1, 1 do
            dir = dir .. "/" .. ss[i]
            io.mkdir(dir)
            -- log.info(tag, "mkdir", dir, r, e)
        end
    end

    -- 找文件
    local path = "/" .. name .. ".json"
    local compressed -- 压缩引擎

    os.remove(path)

    -- 大于一个block-size（flash 4k）
    if fastlz and #data > 4096 then
        path = path .. ".flz"
        compressed = true
        os.remove(path)
    end

    -- 删除历史(到底需不需要)，另外，是否需要备份
    -- if io.exists(path) then
    --     os.remove(path)
    -- end

    -- 压缩
    if compressed then
        data = fastlz.compress(data)
    end

    return io.writeFile(path, data)
end

---删除配置文件
---@param name string 文件名，不带.json后缀
function configs.delete(name)
    log.info(tag, "delete", name)

    -- 找文件
    local path = "/" .. name .. ".json"
    os.remove(path)

    -- 删除压缩版
    if fastlz then
        path = path .. ".flz"
        os.remove(path)
    end

    -- 删除目录
    utils.remove_all(name)
end

---下载配置文件，要求是.json或.json.flz格式
---@param name string 文件名，不带.json后缀
---@param url string 从http服务器下载
function configs.download(name, url)
    log.info(tag, "download", name, url)

    sys.taskInit(function()
        local code, headers, body = http.request("GET", url).wait()
        log.info(tag, "download result", code, body)
        -- 阻塞执行的
        if code == 200 then
            configs.save(name, body)
        end
    end)
end

return configs
