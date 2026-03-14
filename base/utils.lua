--- 工具库
-- @module utils
local utils = {}

--- 定义类
-- @param parent 父类（可选）
-- @return 类
function utils.class(parent)
    local clazz = {}
    clazz.__index = clazz
    clazz.__parent = parent

    function clazz:new(obj)
        -- 继承父类实例
        if parent and parent.new then
            obj = parent:new(obj)
        end
        -- 设置meta
        return setmetatable(obj or {}, self)
    end

    return clazz
end

--- 混合
-- @param obj 参数
function utils.mixin(obj, ...)
    for _, source in ipairs({...}) do
        for k, v in pairs(source) do
            obj[k] = v
        end
    end
    return obj
end

--- 合并多个表
-- @return table
function utils.merge(...)
    local obj = {}
    for _, source in ipairs({...}) do
        for k, v in pairs(source) do
            obj[k] = v
        end
    end
    return obj
end

--- 深度克隆
-- @param obj table
-- @return table
function utils.deep_clone(obj)
    if type(obj) ~= "table" then
        return obj
    end
    local new = {}
    for k, v in pairs(obj) do
        new[k] = utils.deep_clone(v)
    end
    return new
end

--- 自增ID
-- @param first 初始值（可选）
-- @return function 自增闭包
function utils.increment(first)
    local id = 0
    if first then
        id = first - 1
    end
    return function()
        id = id + 1
        return id
    end
end

return utils