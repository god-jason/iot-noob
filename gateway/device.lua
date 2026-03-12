--- 设备类定义
-- 所有协议实现的子设备必须继承Device，并实现标准接口
-- @module device
local Device = {}
Device.__index = Device

local log = iot.logger("device")
local Watcher = require("watcher")

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function Device:new(obj)
    local dev = setmetatable(obj or {}, self)
    dev._values = {}
    dev._modified_values = {}
    dev._thresholds = {} -- 变化阈值
    dev._updated = 0 -- 数据更新时间
    dev._watcher = Watcher:new()
    return dev
end

---  打开
-- @return boolean, error
function Device:open()
    return false, "Device open() 未实现"
end

---  关闭
-- @return boolean, error
function Device:close()
    return false, "Device close() 未实现"
end
---  读值
-- @param key string
-- @return boolean, any|error
function Device:get(key)
    self.__index = key -- 避免self未使用错误提醒
    return false, "Device get(key) 未实现"
end

---  写值
-- @param key string
-- @param value any
-- @return boolean, error
function Device:set(key, value)
    return false, "Device set(key, value) 未实现"
end

---  轮询
-- @return boolean, error
function Device:poll()
    return false, "Device poll() 未实现"
end

function Device:set_threshold(key, threshold)
    self._thresholds[key] = threshold
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

--- 读取值
-- @param key string
-- @return any
function Device:get_value(key)
    local v = self._values[key]
    if not v then
        return nil
    end
    return v.value
end

---  修改值（用于采集）
-- @param key string
-- @param value any
function Device:put_value(key, value)
    log.info("put_value", self.id, key, value)

    local has = false

    local val = {
        value = value,
        time = os.time()
    }

    -- 记录变化的值
    local v = self._values[key]
    if v then
        if v.value ~= value then
            if self._thresholds[key] and type(v.value) == "number" and type(value) == "number" and
                math.abs(v.value - value) < self._thresholds[key] then
                -- 有变化阈值，且在范围之内，不变化
                log.info(key, v.value, value, "change under thresold")
            else
                self._modified_values[key] = val
                has = true
            end
        end
    else
        self._modified_values[key] = val
        has = true
    end

    self._values[key] = val

    -- 监听变化
    if has then
        self.watcher:dispatch(key, value)
    end
end

---  修改多值（用于采集）
-- @param values any
function Device:put_values(values)
    local has = false
    for key, value in pairs(values) do
        local val = {
            value = value,
            time = os.time()
        }

        -- 记录变化的值
        local v = self._values[key]
        if v then
            if v.value ~= value then
                if self._thresholds[key] and type(v.value) == "number" and type(value) == "number" and
                    math.abs(v.value - value) < self._thresholds[key] then
                    -- 有变化阈值，且在范围之内，不变化
                    log.info(key, v.value, value, "change under thresold")
                else
                    self._modified_values[key] = val
                    has = true
                end
            end
        else
            self._modified_values[key] = val
            has = true
        end

        self._values[key] = val
    end

    -- 监听变化
    if has then
        self.watcher:dispatch()
    end
end

--- 监听值变化
function Device:watch(cb)
    return self.watcher:watch(cb)
end

-- 取消监听
function Device:unwatch(id)
    self.watcher:unwatch(id)
end

return Device
