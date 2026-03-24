--- 组件管理器
-- @module components
local components = {}

local _components = {
    -- fan = Fan:new({})
}

local log = iot.logger("components")

-- 注册到全局
_G.components = _components

local settings = require("settings")
local boot = require("boot")

local types = {}

function components.components()
    return _components
end

function components.get(name)
    return _components[name]
end

--- 注册组件类型
function components.register(name, clazz)
    types[name] = clazz
end

--- 创建组件
function components.create(cmp)
    log.info("create", cmp.type, cmp.name)

    local fn = types[cmp.type]
    if not fn then
        --log.error("未知类型组件")
        return false, "未知组件类型" .. cmp.type
    end

    local comp = fn:new(cmp)

    _components[cmp.name] = comp
    return true, comp
end

--- 加载组件
function components.open()
    log.info("load")

    local cms = settings.components
    for k, v in ipairs(cms) do
        local ret, info = components.create(v)
        if not ret then
            return ret, info
        end
    end

    return true
end

boot.register("components", components, "settings")

settings.register("components", {})

return components
