--- 串口类相关
--- @module "Serial"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "Serial"

--- 定义类
--- @class Serial
local Serial = {}

require("links").register("serial", Serial)
local serial = require("serial")


---创建串口实例
---@param opts table
---@return table
function Serial:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = opts.id or "serial-"..opts.port
    obj.port = opts.port or 1
    obj.baud_rate = opts.baud_rate or 9600
    obj.data_bits = opts.data_bits or 8
    obj.stop_bits = opts.stop_bits or 1
    obj.parity = opts.parity or 'N'
    return obj
end

--- 打开
--- @return boolean 成功与否
function Serial:open()
    local ret = serial.open(self.port, self.baud_rate, self.data_bits, self.stop_bits, self.parity)
    if not ret then
        return false
    end

    serial.watch(self.port, function(id, len)
        sys.publish("SERIAL_DATA_" .. id)
    end)

    return ret
end

--- 写数据
--- @param data string 数据
--- @return boolean 成功与否
function Serial:write(data)
    return serial.write(self.port, data)
end

-- 等待数据
--- @param timeout integer 超时 ms
--- @return boolean 成功与否
function Serial:wait(timeout)
    return sys.waitUntil("SERIAL_DATA_" .. self.port, timeout)
end

-- 读数据
--- @return boolean 成功与否
--- @return string|nil 数据
function Serial:read()
    return serial.read(self.port)
end

-- 关闭串口
function Serial:close()
    serial.close(self.port)
end

return Serial
