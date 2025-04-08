--- 产品相关
--- @module "products"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "product"
local products = {}

local configs = require("configs")

local cached_configs = {}

local wanted_configs = {}

--- 加载产品配置
--- @param id any 产品ID
--- @param config any 配置文件
--- @return boolean 成功
--- @return table|nil 配置内容
function products.load_config(id, config)
    -- 取缓存
    if cached_configs[id] == nil then
        cached_configs[id] = {}
    end
    if cached_configs[id][config] ~= nil then
        return true, cached_configs[id][config]
    end

    -- 加载配置文件
    -- local name = "products/" .. id .. "/" .. config
    local name = id .. "/" .. config -- 去掉前缀，兼容luadb
    local ret, data = configs.load(name)
    if not ret then
        wanted_configs[name] = true
        return false
    end

    -- 缓存
    cached_configs[id][config] = data

    return true, data
end

--- 下载产品配置
--- @param id any 产品ID
--- @param config any 配置文件
function products.download(id, config)
    local name = "products/" .. id .. "/" .. config
    local url = "http://iot.busycloud.cn/product/" .. id .. "/" .. config .. ".json"
    configs.download(name, url)
end

--- 获取未成功加载的配置
--- @return boolean
--- @return table
function products.wanted()
    local has = false
    local cs = {}
    for k, v in pairs(wanted_configs) do
        table.insert(cs, k)
        has = true
    end
    return has, cs
end

return products
