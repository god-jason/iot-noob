--- 配置文件相关
-- @module configs
local configs = {}

local tag = "configs"

--local utils = require("utils")

local function luadb_config(name)
    if #name <= 26 then -- 带后缀名，长度不能大于31
        return "/luadb/" .. string.gsub(name, "/", "-") .. ".json"
    end
    local md5 = crypto.md5(name) -- substr(md5, 8, 24)
    return "/luadb/" .. string.sub(md5, 9, 24) .. ".json"
end

---加载配置文件，自动解析json
-- @param name string 文件名，不带.json后缀
-- @return boolean 成功与否
-- @return table|nil
-- @return string 最终文件名
function configs.load(name)
    --log.info(tag, "load", name)

    -- 1、找原始JSON文件hen
    local path = "/" .. name .. ".json"
    -- 2、找压缩的JSON文件
    local path2 = "/" .. name .. ".json.flz"
    -- 3、从luadb中找，（编译时添加）文件名长度限制在31字节。。。
    local path3 = luadb_config(name) -- 要避免重复计算MD5 ？？？

    local compressed = false -- 压缩引擎

    -- 降低启动速度，避免日志输出太快，从而导致丢失
    -- iot.sleep(100)

    if io.exists(path) then
        -- do nothing 找到了未压缩的文件
        log.info(tag, "found", path)
    elseif fastlz and io.exists(path2) then
        compressed = true
        path = path2
    elseif io.exists(path3) then
        path = path3
    else
        --log.info(tag, name, "not found")
        return false
    end

    -- 限制文件大小（780EPM已经到1MB了，不太需要）
    -- local size = io.fileSize(path)
    -- if size > 20000 then
    --     log.info(tag, "too large", path, size)
    --     return false
    -- end

    local data = io.readFile(path)
    --log.info(tag, "from", path, #data)

    -- 解压
    if compressed then
        data = fastlz.uncompress(data, 32 * 1024) -- 最大32KB
    end

    local obj, ret, err = json.decode(data)
    if ret == 1 then
        return true, obj, path
    else
        log.error(tag, "decode failed", path, err, data)
        return false, err
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

    return io.writeFile(path, data), path
end

---删除配置文件
-- @param name string 文件名，不带.json后缀
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
    -- utils.remove_all(name)
end

---下载配置文件，要求是.json或.json.flz格式
-- @param name string 文件名，不带.json后缀
-- @param url string 从http服务器下载
function configs.download(name, url)
    log.info(tag, "download", name, url)

    sys.taskInit(function()
        local code, headers, body = http.request("GET", url).wait()
        log.info(tag, "download result", code, headers, body)
        -- 阻塞执行的
        if code == 200 then
            configs.save(name, body)
        end
    end)
end

return configs
