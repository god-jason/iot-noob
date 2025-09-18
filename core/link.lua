--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- 连接类定义
-- 所有连接必须继承Link，并实现标准接口
-- @module Link
local Link = {}

_G.Link = Link -- 注册到全局变量

---  打开 
-- @return boolean, error
function Link:open()
    self.__index = self -- 避免self未使用错误提醒
    return false, "Link open() must be implemented!"
end

---  关闭 
-- @return boolean, error
function Link:close()
    self.__index = self -- 避免self未使用错误提醒
    return false, "Link close() must be implemented!"
end

---  读取数据
-- @return boolean, string|error
function Link:read()
    self.__index = self -- 避免self未使用错误提醒
    return false, "Link read() must be implemented!"
end

---  写入数据
-- @param data string
-- @return boolean, any|error
function Link:write(data)
    self.__index = data -- 避免self未使用错误提醒
    return false, "Link write(data) must be implemented!"
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Link:wait(timeout)
    self.__index = timeout -- 避免self未使用错误提醒
    return false, "Link wait(timeout) must be implemented!"
end

return Link
