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

    log.info(tag, "open serial", self.id, ret)
    return ret == 0
end

-- 写数据
function Serial:write(data)
    return uart.write(self.id, data)
end

-- 读数据，可能为空
function Serial:read(len)
    return uart.read(self.id, len)
end

-- 关闭串口
function Serial:close()
    uart.close()
    log.info(tag, "close serial", self.id)
end

-- 监听数据
function Serial:watch(cb)
    uart.on(self.id, 'receive', function(id, len)
        local data = uart.read(id, len)
        cb(data)
    end)
end
