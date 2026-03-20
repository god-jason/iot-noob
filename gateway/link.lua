--- 连接类定义
-- 所有连接必须继承Link，并实现标准接口
-- @module link
local Link = require("utils").class(require("event"))


function Link:init()
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

---  写入数据
-- @param data string
-- @return boolean
-- @return error
function Link:write(data)
    return false, "Link write(data) 未实现"
end


return Link
