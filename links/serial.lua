--- 串口连接，继承Link
-- @module link_serial
local Serial = {}
Serial.__index = Serial

local Link = require("link")
setmetatable(Serial, Link) -- 继承Link

require("gateway").register_link("serial", Serial)

---创建串口实例
-- @param opts table
-- @return table
function Serial:new(opts)
    local lnk = Link:new()
    setmetatable(lnk, self)
    lnk.id = opts.id or "serial-" .. opts.port
    lnk.port = opts.port or 1
    lnk.options = opts
    return lnk
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    local ret, obj = iot.uart(self.port, self.options)
    if ret then
        self.uart = obj
    end
    return ret
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    return self.uart:write(data)
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Serial:wait(timeout)
    return self.uart:wait(timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function Serial:read()
    local ret, data = self.uart:read()
    if ret and self.watcher then
        self.watcher(data) -- 转发到监听器
    end
    return ret, data
end

--- 关闭串口
function Serial:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.uart:close()
end

return Serial
