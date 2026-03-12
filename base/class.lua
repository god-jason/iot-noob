--- 类接口
-- @module class
--- 定义类
_G.class = function(object)
    local clazz = {}
    clazz.__index = clazz
    return clazz
end

--- 继承类
_G.extend = function(parent)
    local children = setmetatable({}, parent)
    children.__index = children
    return children
end

--- 实例类
_G.new = function(clazz, object)
    -- return setmetatable(object or {}, class)
    object = object or {}
    setmetatable(object, clazz)
    return object
end
