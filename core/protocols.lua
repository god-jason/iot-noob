--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- 协议相关
-- @module protocols
local protocols = {}

local tag = "protocols"

local factory = {}

function protocols.register(type, class)
    log.info(tag, "register", type)
    factory[type] = class
end

function protocols.create(type, link, opts)
    local f = factory[type]
    if not f then
        return false
    end

    log.info(tag, "create", type)
    return true, f:new(link, opts or {})
end

return protocols
