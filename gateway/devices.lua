--- 所有设备
-- @module devices
local devices = {}

local _devices = {}
_G.devices = _devices

--- 注册设备
function devices.register(id, device)
    iot.emit("DEVICE_REGISTER", device)
    _devices[id] = device
end

--- 反注册设备
function devices.unregister(id)
    iot.emit("DEVICE_UNREGISTER", id)
    _devices[id] = nil
end

--- 所有设备
function devices.devices()
    return _devices
end

--- 获取设备
function devices.get(id)
    return _devices[id]
end

return devices
