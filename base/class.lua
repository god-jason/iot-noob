--- 类接口
-- @module class

--- 定义类
function class(object)
    local clazz = {}
    clazz.__index = clazz
    return clazz
end

--- 继承类
function extend(parent)
    local children = setmetatable({}, parent)
    children.__index = children
    return children
end

--- 实例类
function new(clazz, object)
    --return setmetatable(object or {}, class)
    object = object or {}
    setmetatable(object, clazz)
    return object
end
