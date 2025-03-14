--- 产品相关
--- @module "products"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "product"
local products = {}

local configs = require("configs")

local cache = {}

--- 加载产品配置
--- @param id any 产品ID
--- @param config any 配置文件
--- @return boolean 成功
--- @return table|nil 配置内容
function products.load_config(id, config)
    -- 取缓存
    if cache[id] == nil then
        cache[id] = {}
    end
    if cache[id][config] ~= nil then
        return true, cache[id][config]
    end

    -- 加载配置文件
    local name = "product/" .. id .. "/" .. config
    local ret, data = configs.load(name)
    if not ret then
        -- products.download(id, config)
        return false
    end

    -- 缓存
    cache[id][config] = data

    return true, data
end

--- 下载产品配置
--- @param id any 产品ID
--- @param config any 配置文件
function products.download(id, config)
    local name = "product/" .. id .. "/" .. config
    local url = "http://iot.busycloud.cn/product/" .. id .. "/" .. config .. ".json"
    configs.download(name, url)
end

return products
