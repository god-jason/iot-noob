--- 所有协议
-- @module protocols
local protocols = {}

_G.protocols = protocols

local log = iot.logger("protocols")

local links = require("links")
local boot = require("boot")
local utils = require("utils")

local types = {}

--- 注册协议
function protocols.register(name, clazz)
    types[name] = clazz
end

--- 创建协议
function protocols.create(link, name, opts)
    log.info("create", iot.json_encode(opts))

    local clazz = types[name]
    if not clazz then
        return false, "未知协议类型" .. name
    end

    return true, clazz:new(link, opts)
end

local protocol_instanses = {}

local function create_protocol(link)
    -- 创建协议
    local ret, instanse = protocols.create(link, link.protocol, link.protocol_options or {})
    if not ret then
        return false, instanse
    end

    protocol_instanses[link.id] = instanse

    -- 打开协议
    return utils.call(instanse.open, instanse)
end

--- 创建所有协议
function protocols.open()
    for i, link in pairs(links.links()) do
        if link.protocol and #link.protocol > 0 then
            local ret, info = create_protocol(link)
            if not ret then
                log.error(info)
            end
        end
    end
end

--- 关闭所有协议
function protocols.close()
    for k, instanse in pairs(protocol_instanses) do
        utils.call(instanse.close, instanse)
    end
    protocol_instanses = {}
end

protocols.deps = {"links", "settings"}

-- 注册启动
boot.register("protocols", protocols)

return protocols
