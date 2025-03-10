local tag = "links"
local links = {}

local factory = {}

local configs = require("configs")
local protocols = require("protocols")
--local devices = {}

local cache = {}


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

function links.load()
    local ret, data = configs.load("links")
    if not ret then return false end
    for _, link in ipairs(data) do
        local res, lnk = links.create(link.type, link)
        if res then
            cache[link.id] = lnk
            if link.protocol then
                protocols.create(lnk, link.protocol_options)
                --TODO 实例需要保存下来
            end
        end
    end
    return true
end

return links
