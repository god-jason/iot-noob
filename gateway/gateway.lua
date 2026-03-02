local gateway = {}

local log = iot.logger("gateway")

local Device = require("device")
local devices = require("devices")
local boot = require("boot")

-- 继承标准设备
local GatewayDevice = {}
GatewayDevice.__index = GatewayDevice
setmetatable(GatewayDevice, Device) -- 继承Device

function GatewayDevice:new(obj)
    return setmetatable(Device:new(obj), GatewayDevice)
end

function GatewayDevice:open()

end

function GatewayDevice:get(key)
    -- 查网关变量
    local val = self._values[key]
    if val ~= nil then
        return true, val.value
    end

    -- 查找内联设备
    for k, dev in pairs(devices) do
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

    -- 找不到
    return false, "unkown key"
end

function GatewayDevice:set(key, value)
    -- 查网关变量
    local val = self._values[key]
    if val ~= nil then
        self._values[key] = {
            value = value,
            timestamp = os.time()
        }
        return true
    end

    -- 查找内联设备
    for k, dev in pairs(devices) do
        if dev.set and dev.inline then
            val = dev._values[key]
            if val ~= nil then
                return dev:set(key, value)
            end
        end
    end

    return false, "unkown key"
end

function GatewayDevice:poll()
    for k, dev in pairs(devices) do
        if dev.poll and dev.inline then
            dev:poll()
        end
    end
end


function GatewayDevice:values()
    local values = {}
    for k, dev in pairs(devices) do
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

function GatewayDevice:modified_values(clear)
    local values = {}
    for k, dev in pairs(devices) do
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

local device = GatewayDevice:new({})
gateway.device = device
--devices.register("$gateway$", device)
    
function gateway.update()
    -- 信号强度
    device:set("csq", mobile.csq())

    -- 内存占用
    local total, used, top = rtos.meminfo()
    device:set("memory", math.floor(used / total * 100))

end

function gateway.open()
    device:set("bsp", rtos.bsp())
    device:set("project", PROJECT)
    device:set("version", VERSION)
    device:set("firmware", rtos.firmware())
    device:set("imei", mobile.imei())
    device:set("imsi", mobile.imsi())
    device:set("iccid", mobile.iccid())

    iot.setInterval(gateway.update, 1000)
end

function gateway.close()
    -- iot.clearInterval()
end

gateway.deps = {"settings"}
boot.register("gateway", gateway)

return gateway
