--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- 设备类定义
-- 所有协议实现的子设备必须继承Device，并实现标准接口
-- @module Device
local Device = {}

_G.Device = Device -- 注册到全局变量

local error_unmount = "设备未挂载到连接上"

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function Device:new(obj)
    local dev = obj or {}
    setmetatable(dev, self)
    self.__index = self
    return dev
end

---  打开 
-- @return boolean, error
function Device:open()
    return false, error_unmount
end

---  关闭 
-- @return boolean, error
function Device:close()
    return false, error_unmount
end
---  读值 
-- @param key string
-- @return boolean, any|error
function Device:get(key)
    return false, error_unmount
end

---  写值 
-- @param key string
-- @param value any
-- @return boolean, error
function Device:set(key, value)
    return false, error_unmount
end

---  轮询 
-- @return boolean, error
function Device:poll()
    return false, error_unmount
end

return Device
