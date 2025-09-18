--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- 串口类相关
-- @module link_serial
local Serial = {}

local tag = "Serial"

require("gateway").register_link("serial", Serial)

---创建串口实例
-- @param opts table
-- @return table
function Serial:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = opts.id or "serial-" .. opts.port
    obj.port = opts.port or 1
    obj.baud_rate = opts.baud_rate or 9600
    obj.data_bits = opts.data_bits or 8
    obj.stop_bits = opts.stop_bits or 1
    obj.parity = opts.parity or 'N'
    obj.rs485_gpio = opts.rs485_gpio -- TODO 应该写在网关配置里面
    obj.asking = false
    return obj
end

--- 打开
-- @return boolean 成功与否
function Serial:open()

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

    uart.on(self.port, 'receive', function(id, len)
        sys.publish("SERIAL_DATA_" .. id, len)
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
    return sys.waitUntil("SERIAL_DATA_" .. self.port, timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function Serial:read()
    local len = uart.rxSize(self.port)
    if len > 0 then
        local data = uart.read(self.port, len)
        log.info(tag, "read", self.port, #data)
        return true, data
    end
    return false
end

--- 关闭串口
function Serial:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    uart.close(self.port)
end

return Serial
