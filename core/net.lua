--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- 网络相关
-- @module net
local net = {}

--local tag = "net"

---网络状态
-- @return table
function net.status()
    local ret = mobile.scell()
    ret['csq'] = mobile.csq()
    return ret
end

--- 网络可用状态
-- @return boolean
function net.ready()
    return mobile.status() == 1 -- 网络已经注册
end

return net
