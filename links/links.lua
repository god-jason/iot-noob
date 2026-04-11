--- 所有连接
-- @module links
local links = {}

local _links = {}

_G.links = _links

local log = iot.logger("links")

local database = require("database")
local settings = require("settings")
local protocols = require("protocols")
local boot = require("boot")

--- 创建链接
function links.create(clazz, opts)
    log.info("create", iot.json_encode(opts))

    local link = clazz:new(opts)
    if opts.id and #opts.id > 0 then
        -- 注册到全局
        _links[opts.id] = link
    end
    if opts.name and #opts.name > 0 then
        _links[opts.name] = link
    end

    local ret, info = link:open()
    if not ret then
        return false, info
    end

    local devices = {}

    -- 查找内联设备数据库
    local ds = database.find("inline", "link_id", opts.id)
    for i, d in ipairs(ds) do
        table.insert(devices, d)
    end

    -- 查找设备数据库
    ds = database.find("device", "link_id", opts.id)
    for i, d in ipairs(ds) do
        table.insert(devices, d)
    end

    log.info("连接[", opts.name or opts.id, "]挂载设备数量", #devices)

    -- 遍历设备，查找物模型
    local products = {}
    for i, d in ipairs(devices) do
        if d.product_id then
            table.insert(products, d.product_id)
        end
    end

    -- 协议是按其中一个设备来 TODO 检查协议不一致的问题
    local protocol = link.protocol
    local protocol_options = link.protocol_options

    -- TODO 如果协议是空，则从产品中取

    -- 打开协议
    if protocol and #protocol > 0 then
        -- 创建协议
        local ret, instanse = protocols.create(protocol, {
            link = link,
            devices = devices,
            options = protocol_options or {}
        })
        if not ret then
            return false, instanse
        end

        -- 打开协议
        ret, info = iot.xcall(instanse.open, instanse)
        if not ret then
            return false, info
        end

        -- 协议的实例，比如Modbus主站
        link.protocol_instance = instanse
    end

    return true, link
end

--- 所有连接
function links.links()
    return _links
end

--- 获取连接
function links.get(id)
    return _links[id]
end

function links.open()
    return true
end

-- 做统一依赖
boot.register("links", links, "serials", "splitters", "sockets", "settings")

return links
