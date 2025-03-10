local tag = "protocols"

local protocols = {}

local factory = {}


function protocols.register(type, class)
    factory[type] = class
end


function protocols.create(type, link, opts)
    local f = factory[type]
    if not f then
        return false
    end
    return true, f:new(link, opts)
end


return protocols