--- 配置文件相关
--- @module "configs"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "configs"

local configs = {}

---加载配置文件，自动解析json
---@param name string 文件名，不带.json后缀
---@param compress boolean 压缩
---@return boolean 成功与否
---@return table|nil
function configs.load(name, compress)
    -- 找文件
    local path = "/" .. name .. ".json"
    -- if SD.enable then
    --     path = "/sd" .. path
    -- end
    if compress then
        if fastlz then
            path = path .. ".flz"
        elseif miniz then
            path = path .. ".mz"
        end
    end

    -- 找不到，则下载
    if not io.exists(path) then
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
    if compress then
        if fastlz then
            data = fastlz.uncompress(data)
        elseif miniz then
            data = miniz.uncompress(data)
        end
    end

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
---@param compress boolean 压缩
---@return boolean 成功与否
function configs.save(name, data, compress)
    if type(data) ~= "string" then
        data = json.encode(data)
    end

    -- 找文件
    local path = "/" .. name .. ".json"
    -- if SD.enable then
    --     path = "/sd" .. path
    -- end
    if compress then
        if fastlz then
            path = path .. ".flz"
        elseif miniz then
            path = path .. ".mz"
        end
    end

    -- 删除历史(到底需不需要)，另外，是否需要备份
    if io.exists(path) then
        os.remove(path)
    end

    -- 压缩
    if compress then
        if fastlz then
            data = fastlz.compress(data)
        elseif miniz then
            data = miniz.compress(data)
        end
    end

    return io.writeFile(path, data)
end

return configs
