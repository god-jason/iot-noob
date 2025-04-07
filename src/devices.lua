--- 设备相关
--- @module "devices"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "device"
local devices = {}

local _devices = {}
local _raw = {}

local configs = require("configs")

--- 加载所有设备
function devices.load()
    local ret, data = configs.load("devices")
    if not ret then
        return false
    end
    log.info(tag, "load", data)
    _raw = data
end

--- 过滤某连接的设备
---@param link_id string
---@return table[] 设备列表
function devices.load_by_link(link_id)
    local ds = {}
    for _, dev in ipairs(_raw) do
        if dev.link_id == link_id then
            table.insert(ds, dev)
        end
    end
    return ds
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
