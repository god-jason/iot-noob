--- 所有协议
-- @module protocols
local protocols = {}

_G.protocols = protocols

local log = iot.logger("protocols")

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


return protocols
