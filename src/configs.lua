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
---@return boolean 成功与否
---@return table|nil
function configs.load(name)
    -- 找文件
    local path = "/" .. name .. ".json"
    local path2 = path .. ".flz"
    local path3 = path .. ".mz"

    local zip -- 压缩引擎

    -- 找不到原始文件，则找压缩文件
    if io.exists(path) then
        -- 找到了未压缩的文件
    elseif fastlz and io.exists(path2) then
        zip = fastlz
        path = path2
    elseif miniz and io.exists(path3) then
        zip = miniz
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
    if zip then
        data = zip.uncompress(data)
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
---@return boolean 成功与否
function configs.save(name, data)
    if type(data) ~= "string" then
        data = json.encode(data)
    end

    -- 找文件
    local path = "/" .. name .. ".json"
    local zip -- 压缩引擎

    os.remove(path)

    -- 大于一个block-size（flash 4k）
    if #data > 4096 then
        if fastlz then
            path = path .. ".flz"
            zip = fastlz
            os.remove(path)
        elseif miniz then
            path = path .. ".mz"
            zip = miniz
            os.remove(path)
        end
    end

    -- 删除历史(到底需不需要)，另外，是否需要备份
    -- if io.exists(path) then
    --     os.remove(path)
    -- end

    -- 压缩
    if zip then
        data = zip.compress(data)
    end

    return io.writeFile(path, data)
end

return configs
