--- 所有连接
-- @module links
local links = {}

local _links = {}

_G.links = _links

local log = iot.logger("links")

local settings = require("settings")
local boot = require("boot")
local utils = require("utils")
local protocols = require("protocols")

local types = {}

--- 注册链接
function links.register(name, clazz)
    types[name] = clazz
end

--- 创建链接
function links.create(opts)
    log.info("create", iot.json_encode(opts))

    local clazz = types[opts.type]
    if not clazz then
        return false, "未知链接类型" .. opts.type
    end

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

    -- 打开协议
    if link.protocol and #link.protocol > 0 then
        -- 创建协议
        local ret, instanse = protocols.create(link, link.protocol, link.protocol_options or {})
        if not ret then
            return false, instanse
        end

        -- 打开协议
        ret, info = utils.call(instanse.open, instanse)
        if not ret then
            return false, info
        end

        -- 协议的实例，比如Modbus主站
        link.protocol_instance = instanse
    end

    return true, link
end

--- 加载链接
function links.open()
    log.info("load")
    local lnks = {}

    local cms = settings.links
    for k, v in ipairs(cms) do
        local ret, info = links.create(v)
        if not ret then
            log.error(info)
            iot.emit("error", "打开连接失败" .. info)
        else
            table.insert(lnks, info)
        end
    end

    return true, lnks
end

--- 关闭连接
function links.close()
    for i, s in pairs(_links) do
        if s.protocol_instance then
            utils.call(function()
                s.protocol_instance:close()
            end)
        end
        utils.call(function()
            s:close()
        end)
    end
end

--- 所有连接
function links.links()
    return _links
end

--- 获取连接
function links.get(id)
    return _links[id]
end

links.deps = {"settings"}

settings.register("links", {})
boot.register("links", links)

return links
