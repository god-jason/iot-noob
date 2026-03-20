--- 网关主设备
-- @module master
local master = {}

local log = iot.logger("master")

local settings = require("settings")
local Device = require("device")
local boot = require("boot")

local MasterDevice = {}
MasterDevice.__index = MasterDevice
setmetatable(MasterDevice, Device)

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function MasterDevice:new(obj)
    local dev = setmetatable(Device:new(obj), self)
    dev._children = {} -- 内联子设备
    dev._children_change = {}
    return dev
end

---  读值（具体协议需要继承实现）
-- @param key string
-- @return boolean, any|error
function MasterDevice:get(key)
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
function MasterDevice:set(key, value)
    -- 查找内联设备
    for k, dev in pairs(self._children) do
        local val = dev._values[key]
        if val ~= nil then
            return dev:set(key, value)
        end
    end

    -- 组件绑定变量
    for k, cmp in ipairs(settings.components) do
        if cmp.bindings then
            for k, v in pairs(cmp.bindings) do
                if v == key and cmp.set then
                    cmp:set(k, value)
                    return true
                end
            end
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
function MasterDevice:poll()
    -- 轮询内联设备
    for k, dev in pairs(self._children) do
        dev:poll()
    end
    return true
end

--- 添加子设备
function MasterDevice:attach_children(dev)
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
function MasterDevice:detach_children(id)
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
function MasterDevice:values()
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
function MasterDevice:modified_values(clear)
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

local device = MasterDevice:new({})
master.device = device
-- devices.register("$master$", device)

--- 更新数据
function master.update_status()
    -- 计算内存占用
    local total, used, top = rtos.meminfo()

    device:put_values({
        memory = math.ceil(used / total * 100),
        csq = mobile.csq()
    })
end

--- 打开网关
function master.open()

    -- 组件绑定 组件变量=>网关变量
    for k, cmp in ipairs(settings.components) do
        if cmp.bindings and components[k] then
            components[k].on_change = function(key, value)
                local key2 = cmp.bindings[key]
                device:put_value(key2, value)
            end
        end
    end

    -- 订阅添加子设备
    iot.on("DEVICE_REGISTER", function(device)
        -- 只绑定内联设备
        if device.inline then
            device:attach_children(device)
        end
    end)

    -- 订阅删除子设备
    iot.on("DEVICE_UNREGISTER", function(id)
        device:detach_children(id)
    end)

    -- 放入初始数据
    device:put_values({
        bsp = rtos.bsp(),
        project = PROJECT,
        version = VERSION,
        firmware = rtos.firmware(),
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid()
    })

    iot.setInterval(master.update_status, (settings.master.interval or 1) * 60 * 1000)
end

master.deps = {"settings", "components"}
boot.register("master", master)

settings.register("master", {
    interval = 1
})

return master
