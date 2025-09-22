--- 连接类定义
-- 所有连接必须继承Link，并实现标准接口
-- @module link
local Link = {}
Link.__index = Link

---  创建实例，子类定义可参考
-- @param obj table 连接对象
-- @return boolean, error
function Link:new(obj)
    return setmetatable(obj or {}, self)
end

---  打开
-- @return boolean, error
function Link:open()
    return false, "Link open() must be implemented!"
end

---  关闭
-- @return boolean, error
function Link:close()
    return false, "Link close() must be implemented!"
end

---  读取数据
-- @return boolean, string|error
function Link:read()
    return false, "Link read() must be implemented!"
end

---  写入数据
-- @param data string
-- @return boolean, any|error
function Link:write(data)
    return false, "Link write(data) must be implemented!"
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Link:wait(timeout)
    return false, "Link wait(timeout) must be implemented!"
end

--- 注册监听回调
-- @param cb function(data)
function Link:watch(cb)
    self.watcher = cb
end

return Link
