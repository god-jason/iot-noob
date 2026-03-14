--- 连接类定义
-- 所有连接必须继承Link，并实现标准接口
-- @module link
local Link = {}
Link.__index = Link

local Event = require("event")

---  创建实例，子类定义可参考
-- @param obj table 连接对象
-- @return Link 对象
function Link:new(obj)
    return setmetatable(Event:new(obj), self)
end

---  打开
-- @return boolean
-- @return string error
function Link:open()
    return false, "Link open() 未实现"
end

---  关闭
function Link:close()
    return false, "Link close() 未实现"
end

---  读取数据
-- @return boolean 成功与否
-- @return string|error
function Link:read()
    return false, "Link read() 未实现"
end

---  写入数据
-- @param data string
-- @return boolean
-- @return error
function Link:write(data)
    return false, "Link write(data) 未实现"
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
-- @return intger 长度
function Link:wait(timeout)
    return false, "Link wait(timeout) 未实现"
end

--- 开启透传
-- @param peer Link 对等连接
function Link:pipe(peer)
    self.peer = peer
end

return Link
