local tag = "SERIAL"

-- 定义类
local Serial = {}

require("links").register("serial", Serial)
local serial = require("serial")

function Serial:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = opts.id or 1
    obj.baud_rate = opts.baud_rate or 9600
    obj.data_bits = opts.data_bits or 8
    obj.stop_bits = opts.stop_bits or 1
    obj.parity = opts.parity or 'N'
    return obj
end

-- 打开
function Serial:open()
    local ret = serial.open(self.id, self.baud_rate, self.data_bits, self.stop_bits, self.parity)
    if not ret then
        return false
    end

    serial.watch(self.id, function(id, len)
        sys.publish("SERIAL_DATA_" .. id)
    end)

    log.info(tag, "open", self.id, ret)
    return ret
end

-- 写数据
function Serial:write(data)
    return serial.write(self.id, data)
end

-- 等待数据
function Serial:wait(timeout)
    return sys.waitUtil("SERIAL_DATA_" + self.id, timeout)
end

-- 读数据
function Serial:read()
    return serial.read(self.id)
end

-- 关闭串口
function Serial:close()
    serial.close(self.id)
    log.info(tag, "close", self.id)
end

return Serial
