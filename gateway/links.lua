--- 所有连接
-- @module links
local links = {}

local _links = {}

_G.links = _links

local log = iot.logger("links")

local protocols = require("protocols")

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

    -- 打开协议
    if link.protocol and #link.protocol > 0 then
        -- 创建协议
        local ret, instanse = protocols.create(link, link.protocol, link.protocol_options or {})
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

return links
