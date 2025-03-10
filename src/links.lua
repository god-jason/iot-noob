local tag = "links"
local links = {}

local factory = {}


--local devices = {}


function links.register(type, class)
    factory[type] = class   
end


function links.create(type, opts)
    local f = factory[type]
    if not f then
        return false
    end
    return true, f:new(opts)
end




return links