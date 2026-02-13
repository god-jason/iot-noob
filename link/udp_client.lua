--- UDP客户端，继承Link
-- @module udp_client
local UdpClient = {}
UdpClient.__index = UdpClient

local Link = require("link")
setmetatable(UdpClient, Link) -- 继承Link

require("gateway").register("udp-client", UdpClient)

---创建TCP实例
-- @param opts table
-- @return table
function UdpClient:new(opts)
    opts = opts or {}
    opts.is_udp = true
    local obj = Link:new()
    setmetatable(obj, self)
    obj.id = opts.id or "tcp-" .. opts.host .. ":" .. opts.port
    obj.options = opts
    return obj
end

--- 打开
-- @return boolean 成功与否
function UdpClient:open()
    self.socket = iot.socket(self.options)
    return self.socket:open()
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function UdpClient:write(data)
    return self.socket:write(data)
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function UdpClient:wait(timeout)
    return self.socket:wait(timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function UdpClient:read()
    return self.socket:read()
end

--- 关闭
function UdpClient:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.socket:close()
end

return UdpClient
