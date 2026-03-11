--- 协议类定义， 此文件为参考，需实现相同的new,open,close接口
-- @module protocol
local Protocol = {}
Protocol.__index = Protocol

---  创建实例，子类定义可参考
-- @param obj table 协议对象
-- @return Protocol 对象
function Protocol:new(link, obj)
    local ins = setmetatable(obj or {}, self)
    ins.link = link
    return ins
end

---  打开
-- @return boolean
-- @return string error
function Protocol:open()
    return false, "Protocol open() 未实现"
end

---  关闭
function Protocol:close()
    return false, "Protocol close() 未实现"
end

---  读取数据
-- @return boolean 成功与否
-- @return string|error
function Protocol:read()
    return false, "Protocol read() 未实现"
end

---  写入数据
-- @param data string
-- @return boolean
-- @return error
function Protocol:write(data)
    return false, "Protocol write(data) 未实现"
end

return Protocol
