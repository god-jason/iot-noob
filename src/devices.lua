--- 设备相关
--- @module "devices"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag     = "device"
local devices = {}

local _devices = {}


local configs = require("configs")

function devices.load_by_link(link)
    --TODO 更好的加载方式

    return configs.load("devices/"..link)
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
