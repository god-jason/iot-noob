--- 设备类定义
-- 所有协议实现的子设备必须继承Device，并实现标准接口
-- @module device
local Device = {}
Device.__index = Device

local utils = require("utils")
local log = iot.logger("device")

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function Device:new(obj)
    local dev = setmetatable(obj or {}, self)
    dev._values = {}
    dev._modified_values = {}
    dev._thresholds = {} -- 变化阈值
    dev._updated = 0 -- 数据更新时间
    dev._handlers = {}
    return dev
end

---  打开
-- @return boolean, error
function Device:open()
    return true
end

---  关闭
-- @return boolean, error
function Device:close()
    return true
end
---  读值
-- @param key string
-- @return boolean, any|error
function Device:get(key)
    return true, self._values[key]
end

---  写值
-- @param key string
-- @param value any
-- @return boolean, error
function Device:set(key, value)
    self._values[key] = value
    return true
end

---  轮询
-- @return boolean, error
function Device:poll()
    return true
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

    -- 变化时间
    self._updated = os.time()

    -- 监听变化
    if has then
        -- self.watcher:dispatch(key, value)
        self:emit("change", {
            [key] = value
        })
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

    -- 变化时间
    self._updated = os.time()

    -- 监听变化
    if has then
        -- self.watcher:dispatch()
        self:emit("change", values)
    end
end


--- 订阅消息
-- @param name 名称
-- @param fn 回调
function Device:on(name, fn)
    if not self._handlers[name] then
        self._handlers[name] = {}
    end
    table.insert(self._handlers[name], {
        callback = fn
    })
    return function()
        self:off(name, fn)
    end
end

--- 单次订阅
-- @param name 名称
-- @param fn 回调
function Device:once(name, fn)
    if not self._handlers[name] then
        self._handlers[name] = {}
    end
    table.insert(self._handlers[name], {
        once = true,
        callback = fn
    })
    return function()
        self:off(name, fn)
    end
end

--- 取消订阅
-- @param name 名称
-- @param fn 回调，如果为空，则取消其全部订阅
function Device:off(name, fn)
    if not fn then
        self._handlers[name] = nil
        return
    end

    local list = self._handlers[name]
    if list then
        for i = #list, 1, -1 do
            if list[i].callback == fn then
                table.remove(list, i)
            end
        end
    end
end

--- 发送消息
-- @param name 名称
function Device:emit(name, ...)
    local list = self._handlers[name]
    if not list then
        return
    end
    -- 依次回调
    for i, v in ipairs(list) do
        utils.call(v.callback, ...)
    end
    -- 删除once
    for i = #list, 1, -1 do
        if list[i].once then
            table.remove(list, i)
        end
    end
end


return Device
