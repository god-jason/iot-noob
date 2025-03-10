local tag = "SERIAL"

--定义类
local Serial = {}

require("links").register("serial", Serial)

function Serial:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = opts.id or 1
    obj.baud_rate = opts.baud_rate or 9600
    obj.data_bits = opts.data_bits or 8
    obj.stop_bits = opts.stop_bits or 1
    if opts.parity == 'N' or opts.parity == 'n' then
        obj.parity = uart.NONE
    elseif opts.parity == 'E' or opts.parity == 'e' then
        obj.parity = uart.Even
    elseif opts.parity == 'O' or opts.parity == 'o' then
        obj.parity = uart.Odd
    else
        obj.parity = uart.NONE
    end
    obj.rs485_gpio = opts.rs485_gpio
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

    log.info(tag, "open", self.id, ret)
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
    log.info(tag, "close", self.id)
end

return Serial