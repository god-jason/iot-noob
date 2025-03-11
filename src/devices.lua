local tag     = "device"
local devices = {}

local _devices = {}


local configs = require("configs")

function devices.load_by_link(id)
    --TODO 更好的加载方式
    
    return configs.load("devices/"..id)
end


---获取设备实例
---@param id string ID
---@return table
function devices.get(id)
    return _devices[id]
end

---设置设备实例
---@param id any
---@param dev any
function devices.set(id, dev)
    _devices[id] = dev
end

return devices
