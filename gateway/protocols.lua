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
function protocols.create(name, opts)
    log.info("create", name)

    local clazz = types[name]
    if not clazz then
        return false, "未知协议类型" .. name
    end

    return true, clazz:new(opts)
end

return protocols
