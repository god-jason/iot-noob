--- 连接相关
--- @module "links"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20

local tag = "links"
local links = {}

local factory = {}

local configs = require("configs")
local protocols = require("protocols")
--local devices = {}

local cache = {}

--- 注册连接类
--- @param type string 类型
--- @param class table 类
function links.register(type, class)
    factory[type] = class
end

---创建连接实例
---@param type string 类型
---@param opts table 参数
---@return boolean 成功与否
---@return table|nil 连接实例
function links.create(type, opts)
    local f = factory[type]
    if not f then
        return false
    end
    return true, f:new(opts)
end

--- 加载实例
function links.load()
    local ret, data = configs.load("links")
    if not ret then return false end
    for _, link in ipairs(data) do
        local res, lnk = links.create(link.type, link)
        if res then
            cache[link.id] = lnk
            if link.protocol then
                protocols.create(lnk, link.protocol_options)
                --TODO 实例需要保存下来
            end
        end
    end
    return true
end

return links
