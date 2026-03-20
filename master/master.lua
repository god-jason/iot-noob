--- 网关主设备
-- @module master
local master = {}

local log = iot.logger("master")

local Device = require("device")
local devices = require("devices")
local boot = require("boot")

-- 继承标准设备
local MasterDevice = {}
MasterDevice.__index = MasterDevice
setmetatable(MasterDevice, Device) -- 继承Device

function MasterDevice:new(obj)
    return setmetatable(Device:new(obj), MasterDevice)
end

function MasterDevice:open()

end

function MasterDevice:get(key)
    -- 查找内联设备
    for k, dev in pairs(devices.devices()) do
        if dev.get and dev.inline then
            val = dev._values[key]
            if val ~= nil then
                local ret, value = dev:get(key)
                if ret then
                    return ret, value
                end
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

function MasterDevice:set(key, value)

    -- 查找内联设备
    for k, dev in pairs(devices.devices()) do
        if dev.set and dev.inline then
            val = dev._values[key]
            if val ~= nil then
                return dev:set(key, value)
            end
        end
    end

    -- 查网关变量
    -- local val = self._values[key]
    -- if val ~= nil then
    self._values[key] = {
        value = value,
        timestamp = os.time()
    }
    return true
end

function MasterDevice:poll()
    for k, dev in pairs(devices.devices()) do
        if dev.poll and dev.inline then
            dev:poll()
        end
    end
end

function MasterDevice:values()
    local values = {}
    for id, dev in pairs(devices.devices()) do
        if dev._values and dev.inline then
            for k, v in pairs(dev._values) do
                values[k] = v
            end
        end
    end

    for k, v in pairs(self._values) do
        values[k] = v
    end

    return values
end

function MasterDevice:modified_values(clear)
    local values = {}
    for id, dev in pairs(devices.devices()) do
        if dev.modified_values and dev.inline then
            for k, v in pairs(dev:modified_values(clear)) do
                values[k] = v
            end
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

local device = MasterDevice:new(Device:new({}))
master.device = device
-- devices.register("$master$", device)

--- 更新数据
function master.update_status()
    -- 信号强度
    device:put_value("csq", mobile.csq())

    -- 内存占用
    local total, used, top = rtos.meminfo()
    device:put_value("memory", math.floor(used / total * 100))
end

--- 打开网关
function master.open()
    device:put_value("bsp", rtos.bsp())
    device:put_value("project", PROJECT)
    device:put_value("version", VERSION)
    device:put_value("firmware", rtos.firmware())
    device:put_value("imei", mobile.imei())
    device:put_value("imsi", mobile.imsi())
    device:put_value("iccid", mobile.iccid())

    iot.setInterval(master.update_status, 30000)
end

--- 关闭网关
function master.close()
    -- iot.clearInterval()
end

master.deps = {"settings"}
boot.register("master", master)

return master
