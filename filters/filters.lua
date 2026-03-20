--- 所有过滤器
-- @module filters
local filters = {}

_G.filters = filters

local log = iot.logger("filters")

local boot = require("boot")
local utils = require("utils")

local types = {}

--- 注册协议
function filters.register(name, clazz)
    types[name] = clazz
end

--- 创建协议
function filters.create(name, opts)
    log.info("create", iot.json_encode(opts))

    local clazz = types[name]
    if not clazz then
        return false, "未知滤波类型" .. name
    end

    return true, clazz:new(opts)
end

return filters
