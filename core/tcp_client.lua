--- TCP客户端，继承Link
-- @module tcp_client
local TcpClient = {}
TcpClient.__index = TcpClient

local Link = require("link")
setmetatable(TcpClient, Link) -- 继承Link

require("gateway").register("tcp-client", TcpClient)

---创建TCP实例
-- @param opts table
-- @return table
function TcpClient:new(opts)
    opts = opts or {}
    local obj = Link:new()
    setmetatable(obj, self)
    obj.id = opts.id or "tcp-" .. opts.host .. ":" .. opts.port
    obj.options = opts
    return obj
end

--- 打开
-- @return boolean 成功与否
function TcpClient:open()
    self.socket = iot.socket(self.options)
    return self.socket:open()
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function TcpClient:write(data)
    return self.socket:write(data)
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function TcpClient:wait(timeout)
    return self.socket:wait(timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function TcpClient:read()
    return self.socket:read()
end

--- 关闭
function TcpClient:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.socket:close()
end

return TcpClient
