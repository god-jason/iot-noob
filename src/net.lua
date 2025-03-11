local tag = "net"
local net = {}


function net.status()
    local ret = mobile.scell()
    ret['csq'] = mobile.csq()
    return ret
end

function net.ready()
    return mobile.status() == 1 --网络已经注册
end

return net
