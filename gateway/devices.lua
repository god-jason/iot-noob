-- local log = iot.logger("devices")
local devices = {}

local _devices = {}
_G.devices = _devices

-- 注册设备
function devices.register(id, device)
    _devices[id] = device
end

-- 反注册设备
function devices.unregister(id)
    _devices[id] = nil
end

function devices.devices()
    return _devices
end

function devices.get(id)
    return _devices[id]
end

return devices
