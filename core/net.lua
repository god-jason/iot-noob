--- 网络相关
--- @module "net"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "net"
local net = {}

---网络状态
---@return table
function net.status()
    local ret = mobile.scell()
    ret['csq'] = mobile.csq()
    return ret
end

--- 网络可用状态
---@return boolean
function net.ready()
    return mobile.status() == 1 -- 网络已经注册
end

return net
