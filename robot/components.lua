local log = iot.logger("components")

local components = {}

local _components = {
    -- fan = Fan:new({})
}

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

-- 注册组件
function components.register(name, clazz)
    types[name] = clazz
end

-- 创建组件
function components.create(cmp)
    log.info("create", iot.json_encode(cmp))

    local fn = types[cmp.type]
    if not fn then
        return false, "unkown type" .. cmp.type
    end

    local comp = fn:new(cmp)

    _components[cmp.name] = comp
    return true, comp
end

-- 加载组件
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

components.deps = {"settings"}

boot.register("components", components)

settings.register("components", {})

return components
