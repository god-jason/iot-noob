--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- 串口类相关
-- @module Serial
local Serial = {}

local tag = "Serial"

require("links").register("serial", Serial)
local serial = require("serial")

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
    obj.asking = false
    return obj
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    local ret = serial.open(self.port, self.baud_rate, self.data_bits, self.stop_bits, self.parity)
    if not ret then
        return false
    end

    serial.watch(self.port, function(id, len)
        sys.publish("SERIAL_DATA_" .. id, len)
    end)

    return ret
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    return serial.write(self.port, data)
end

-- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Serial:wait(timeout)
    return sys.waitUntil("SERIAL_DATA_" .. self.port, timeout)
end

-- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function Serial:read()
    return serial.read(self.port)
end

-- 关闭串口
function Serial:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    serial.close(self.port)
end

-- 询问
-- @param request string 发送数据
-- @param len integer 期望长度
-- @return boolean 成功与否
-- @return string 返回数据
function Serial:ask(request, len)

    -- 重入锁，等待其他操作完成
    while self.asking do
        sys.wait(100)
    end
    self.asking = true

    -- log.info(tag, "ask", request, len)
    if request ~= nil and #request > 0 then
        local ret = self:write(request)
        if not ret then
            log.error(tag, "write failed")
            self.asking = false
            return false
        end
    end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    repeat
        -- TODO 应该不是每次都要等待
        local ret = self:wait(self.timeout)
        if not ret then
            log.error(tag, "read timeout")
            self.asking = false
            return false
        end

        local r, d = self:read()
        if not r then
            log.error(tag, "read failed")
            self.asking = false
            return false
        end
        buf = buf .. d
    until #buf >= len

    self.asking = false
    return true, buf
end

return Serial
