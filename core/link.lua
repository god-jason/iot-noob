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
-- @param key string
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

return Link
