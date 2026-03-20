--- 串口连接，继承Link
-- @module serial
local Serial = require("utils").class(require("event"))

local log = iot.logger("serial")

-- 注册连接类型
local links = require("links")
links.register("serial", Serial)

---创建串口实例
-- @param opts table
-- @return table
function Serial:init()
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    local ret, port = iot.uart(self.port, self)
    if not ret then
        return false, port
    end

    -- 监听数据
    port:on_data(function(data)
        log.info("serial data", self.port, data:toHex())
        self:emit("data", data)
    end)

    self.uart = port
    return true
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    log.info("write", self.port, data:toHex())
    return self.uart:write(data)
end

--- 关闭串口
function Serial:close()
    -- 关闭协议
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.uart:close()
    self:emit("close")
end

return Serial
