--- 工具库
-- @module utils
local utils = {}

-- 递归调用 init（从根到当前类）
local function call_init_chain(cls, obj)
    if cls.__parent then
        call_init_chain(cls.__parent, obj)
    end

    -- 原始类的 init（避免子类覆盖）
    local init = rawget(cls, "init")
    if init then
        init(obj)
    end
end

--- 定义类
-- @param parent 父类（可选）
-- @return 类
function utils.class(parent)
    local cls = {}
    cls.__index = cls
    cls.__parent = parent
    cls.super = parent

    if parent then
        setmetatable(cls, {
            __index = parent
        })
    end

    function cls:new(obj)
        obj = setmetatable(obj or {}, self)
        -- 调用整个继承链的 init
        call_init_chain(self, obj)
        return obj
    end

    return cls
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

--- 判断是否是数组
-- @param t 表
-- @return boolean
function utils.is_array(t)
    if type(t) ~= "table" then
        return false
    end
    local i = 1
    for k, _ in pairs(t) do
        if k ~= i then
            return false
        end
        i = i + 1
    end
    return true
end

--- 安全调用
-- @param fn 函数， 第一个返回值 代表成功与否，第二个返回值 代表结果 或 错误
-- @param boolean 成功与否
-- @param any 结果 或 错误
function utils.call(fn, ...)
    local ret, res, info = pcall(fn, ...)
    if not ret then
        iot.emit("error", res)
        return false, res
    end
    return res, info
end

return utils
