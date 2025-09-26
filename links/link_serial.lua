--- 串口类相关
-- @module link_serial
local Serial = {}

local tag = "Serial"

require("gateway").register_link("serial", Serial)

---创建串口实例
-- @param obj table
-- @return table
function Serial:new(obj)
    local lnk = obj or {}
    setmetatable(lnk, self)
    self.__index = self
    lnk.id = lnk.id or "serial-" .. lnk.port
    lnk.port = lnk.port or 1
    lnk.baud_rate = lnk.baud_rate or 9600
    lnk.data_bits = lnk.data_bits or 8
    lnk.stop_bits = lnk.stop_bits or 1
    lnk.parity = lnk.parity or 'N'
    lnk.rs485_gpio = lnk.rs485_gpio -- TODO 应该写在网关配置里面
    lnk.asking = false
    return lnk
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    log.info(tag, "open", self.id, self.port, self.baud_rate, self.data_bits, self.stop_bits, self.parity,
        self.rs485_gpio)

    -- 校验表示
    local p = uart.None
    if self.parity == 'N' or self.parity == 'n' then
        p = uart.None
    elseif self.parity == 'E' or self.parity == 'e' then
        p = uart.Even
    elseif self.parity == 'O' or self.parity == 'o' then
        p = uart.Odd
    end

    local ret =
        uart.setup(self.port, self.baud_rate, self.data_bits, self.stop_bits, p, uart.LSB, 1024, self.rs485_gpio)

    -- local ret = uart.setup(self.port, self.baud_rate, self.data_bits, self.stop_bits, p, uart.LSB, 1024,
    --     self.rs485_gpio, 1, 20000)

    uart.on(self.port, 'receive', function(id, len)
        --log.info(tag, "receive", id, len)
        sys.publish("SERIAL_DATA_" .. self.port, len)
    end)

    return ret
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    local len = uart.write(self.port, data)
    log.info(tag, "write", self.port, len)
    return len > 0, len
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Serial:wait(timeout)
    log.info(tag, "wait", self.port, timeout)
    return sys.waitUntil("SERIAL_DATA_" .. self.port, timeout)
end

--- 读数据
-- @param len integer 期待长度
-- @return boolean 成功与否
-- @return string|nil 数据
function Serial:read(len)
    local data = uart.read(self.port, len)
    if #data > 0 then        
        --log.info(tag, "read", self.port, #data, data:toHex())
        if self.watcher then
            self.watcher(data) -- 转发到监听器
        end
        return true, data
    end
    return false, "no data"
end

--- 关闭串口
function Serial:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    uart.close(self.port)
end

return Serial
