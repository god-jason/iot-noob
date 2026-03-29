--- 设备类定义
-- 所有协议实现的子设备必须继承Device，并实现标准接口
-- @module device
local Device = require("utils").class(require("event"))

local log = iot.logger("Device")

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function Device:init()
    log.info("Device:init")
    self._values = {}
    self._modified_values = {}
    self._thresholds = {} -- 变化阈值
    self._updated = 0 -- 数据更新时间
    self._handlers = {}
    self._children = {} -- 内联子设备
    self._children_change = {}
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

---  读值（具体协议需要继承实现）
-- @param key string
-- @return boolean, any|error
function Device:get(key)
    -- 查找内联设备
    for k, dev in pairs(self._children) do
        local val = dev._values[key]
        if val ~= nil then
            local ret, value = dev:get(key)
            if ret then
                return ret, value
            end
        end
    end

    -- 查网关变量
    local val = self._values[key]
    if val ~= nil then
        return true, val.value
    end

    -- 找不到
    return false, "值不存在"
end

---  写值（具体协议需要继承实现）
-- @param key string
-- @param value any
-- @return boolean, error
function Device:set(key, value)
    -- 查找内联设备
    for k, dev in pairs(self._children) do
        local val = dev._values[key]
        if val ~= nil then
            return dev:set(key, value)
        end
    end

    -- 基础处理
    self._values[key] = {
        value = value,
        time = os.time()
    }

    -- self.put_value(key, value)
    return true
end

---  轮询
-- @return boolean, error
function Device:poll()
    -- 轮询内联设备
    for k, dev in pairs(self._children) do
        dev:poll()
    end
    return true
end

--- 添加子设备
function Device:attach_children(dev)
    log.info(self.id, "attach_children", dev.id)
    
    -- 订阅子设备变化
    local cancel = dev:on("change", function(values)
        self:emit("change", values)
    end)

    for i, v in ipairs(self._children) do
        -- 替换
        if v.id == dev.id then
            self._children[i] = dev
            self._children_change[i]()
            self._children_change[i] = cancel
            return
        end
    end

    table.insert(self._children, dev)
    table.insert(self._children_change, cancel)
end

--- 删除子设备
function Device:detach_children(id)
    for i, v in ipairs(self._children) do
        -- 替换
        if v.id == id then
            self._children_change[i]()

            table.remove(self._children, i)
            table.remove(self._children_change, i)
            return
        end
    end
end

---  全部变量
-- @return table k->{value->any, time->int}
function Device:values()
    local values = {}
    for id, dev in pairs(self._children) do
        for k, v in pairs(dev._values) do
            values[k] = v
        end
    end
    for k, v in pairs(self._values) do
        values[k] = v
    end
    return values
end

---  变化的变量
-- @param clear boolean 清空变化
-- @return table k->{value->any, time->int}
function Device:modified_values(clear)
    local values = {}
    for id, dev in pairs(self._children) do
        for k, v in pairs(dev:modified_values(clear)) do
            values[k] = v
        end
    end
    for k, v in pairs(self._modified_values) do
        values[k] = v
    end
    if clear then
        self._modified_values = {}
    end
    return values
end

-- 设备变化阈值
function Device:set_threshold(key, threshold)
    self._thresholds[key] = threshold
end

--- 读取值
-- @param key string
-- @return any
function Device:get_value(key)
    local v = self._values[key]
    if not v then
        return false, "值不存在"
    end
    return true, v.value
end

---  修改值（用于采集）
-- @param key string
-- @param value any
function Device:put_value(key, value)
    log.info("put_value", self.id, key, value)
    if type(key) == "table" then
        return self:put_values(key)
    end

    local has_change = false

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
                has_change = true
            end
        end
    else
        self._modified_values[key] = val
        has_change = true
    end

    self._values[key] = val

    -- 变化时间
    self._updated = os.time()

    -- 监听变化
    if has_change then
        -- self.watcher:dispatch(key, value)
        self:emit("change", {
            [key] = value
        })
    end
end

---  修改多值（用于采集） !!! 不能随意覆盖，否则会引起mirrors change死循环
-- @param values any
function Device:put_values(values)
    local has = false
    local change = {}

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
            change[key] = value
            has = true
        end

        self._values[key] = val
    end

    -- 变化时间
    self._updated = os.time()

    -- 监听变化
    if has then
        -- self.watcher:dispatch()
        self:emit("change", change)
    end
end

return Device
