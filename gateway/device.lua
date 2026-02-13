--- 设备类定义
-- 所有协议实现的子设备必须继承Device，并实现标准接口
-- @module device
local Device = {}
Device.__index = Device

-- _G.Device = Device -- 注册到全局变量

local error_unmount = "设备未挂载到连接上"

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function Device:new(obj)
    local dev = setmetatable(obj or {}, self)
    dev._values = {}
    dev._modified_values = {}
    dev._updated = 0 -- 数据更新时间
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
    self.__index = key -- 避免self未使用错误提醒
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

---  变量
-- @return table k->{value->any, time->int}
function Device:values()
    return self._values
end

---  变化的变量
-- @param clear boolean 清空变化
-- @return table k->{value->any, time->int}
function Device:modified_values(clear)
    local ret = self._modified_values
    if clear then
        self._modified_values = {}
    end
    return ret
end

---  修改值（用于读取）
-- @param key string
-- @param value any
function Device:put_value(key, value)
    log.info("Device", "put_value", self.id, key, value)

    local val = {
        value = value,
        time = os.time()
    }

    -- 记录变化的值
    local v = self._values[key]
    if v then
        if v.value ~= value then
            self._modified_values[key] = val
        end
    end

    self._values[key] = val
end

return Device
