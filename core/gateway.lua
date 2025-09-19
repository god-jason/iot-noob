--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 网关管理
-- @module gateway
local gateway = {}

local tag = "gateway"

local database = require("database")

-- 所有设备实例
local _devices = {}

--- 注册设备实例
-- @param id string 设备ID
-- @param dev Device 子类实例
function gateway.register_device_instanse(id, dev)
    _devices[id] = dev
end

--- 反注册设备实例
-- @param id string 设备ID
function gateway.unregister_device_instanse(id)
    table.remove(_devices, id)
end

--- 获得设备实例
-- @param id string 设备ID
-- @return Device 子实例
function gateway.get_device_instanse(id)
    return _devices[id]
end

--- 获得所有设备实例
-- @return table id->Device 实例
function gateway.get_all_device_instanse()
    return _devices
end

--- 连接类
local links = {}

--- 注册连接类
-- @param name string 类名
-- @param class Object 类定义
function gateway.register_link(name, class)
    links[name] = class
end

--- 所有连接实例
local _links = {}

--- 注册连接实例
-- @param id string 连接ID
-- @param lnk Link 子类实例
function gateway.register_link_instanse(id, lnk)
    _links[id] = lnk
end

--- 反注册连接实例
-- @param id string 连接ID
function gateway.unregister_link_instanse(id)
    table.remove(_links, id)
end

--- 获得连接实例
-- @param id string 连接ID
-- @return Device 子实例
function gateway.get_link_instanse(id)
    return _links[id]
end

--- 协议类型
local protocols = {}

--- 注册协议
-- @param name string 类名
-- @param class Object 类定义
function gateway.register_protocol(name, class)
    protocols[name] = class
end

--- 创建连接
-- @param type string 连接类型
-- @param opts table 参数
-- @return boolean 成功与否
-- @return Link|error 实例
function gateway.create_link(type, opts)
    local link = links[type]
    if not link then
        return false, "找不到连接类"
    end

    -- return true, link:new(opts)
    local lnk = link:new(opts or {})
    local ret, err = lnk:open()
    log.info(tag, "open link", link.id, ret, err)
    if not ret then
        return false, err
    end

    _links[lnk.id] = lnk -- 注册实例

    -- 没有协议，直接返回，可能是透传
    if not lnk.protocol then
        return true, lnk
    end

    local protocol = protocols[lnk.protocol]
    if not protocol then
        return true, lnk
    end

    local instanse = protocol:new(lnk, lnk.protocol_options or {})
    ret, err = instanse:open()
    log.info(tag, "open protocol", ret, err)

    if ret then
        -- 协议实例保存下来
        lnk.instanse = instanse
    end

    return true, lnk
end

--- 关闭连接
-- @param id string 连接ID
function gateway.close_link(id)
    local lnk = _links[id]
    if not lnk then
        lnk:close()
        table.remove(_links, id)
    end
end

--- 加载所有连接
function gateway.load_links()
    log.info(tag, "load links")

    local lns = database.find("link")
    if #lns == 0 then
        return
    end

    for _, link in ipairs(lns) do
        log.info(tag, "load link", link.id, link.type)
        local ret, lnk = gateway.create_link(link.type, link)
        log.info(tag, "create link", link.id, link.type, ret, lnk)
    end
end

-- 创建设备
-- @param dev table 设备
-- @return boolean 成功与否
-- @return Link|error 实例
-- function gateway.create_device(dev)
--     local lnk = _links[dev.link_id]
--     if lnk and lnk.instanse then
--         lnk.instanse.attach(dev)
--     else
--         _devices[dev.id] = Device:new(dev)
--     end
-- end

-- 加载所有设备
-- function gateway.load_devices()
--     local dvs = database.find("device")
--     if #dvs == 0 then
--         return
--     end

--     for _, dev in ipairs(dvs) do
--         gateway.create_device(dev)
--     end

-- end

return gateway
