local tag = "SERIAL"

--定义类
Serial = {}

function Serial:new(id, baud_rate, data_bits, stop_bits, parity, rs485_gpio)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = id
    obj.baud_rate = baud_rate
    obj.data_bits = data_bits
    obj.stop_bits = stop_bits
    obj.baud_rate = baud_rate
    if parity == 'N' or parity == 'n' then
        obj.parity = uart.NONE
    elseif parity == 'E' or parity == 'e' then
        obj.parity = uart.Even
    elseif parity == 'O' or parity == 'o' then
        obj.parity = uart.Odd
    else
        obj.parity = uart.NONE
    end
    obj.rs485_gpio = rs485_gpio
    return obj
end

-- 打开
function Serial:open()
    local ret
    if self.rs485_gpio == nil then
        ret = uart.setup(self.id, self.baud_rate, self.data_bits, self.stop_bits, self.parity)
    else
        ret = uart.setup(self.id, self.baud_rate, self.data_bits, self.stop_bits, self.parity,
            uart.MSB, 1024, self.rs485_gpio)
    end

    uart.on(self.id, 'receive', function(id, len)
        sys.publish("SERIAL_DATA_" .. id)
    end)

    log.info(tag, "open serial", self.id, ret)
    return ret == 0
end

-- 写数据
function Serial:write(data)
    local len = uart.write(self.id, data)
    return len > 0, len
end

-- 等待数据
function Serial:wait(timeout)
    return sys.waitUtil("SERIAL_DATA_" + self.id, timeout)
end

-- 读数据
function Serial:read()
    -- 检测缓冲区是否有数据
    local len = uart.rxSize(self.id)
    if len > 0 then
        local data = uart.read(self.id, len)
        return true, data
    end
    return false
end

-- 关闭串口
function Serial:close()
    uart.close()
    log.info(tag, "close serial", self.id)
end

return Serial