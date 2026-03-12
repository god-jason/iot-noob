

--- 所有连接
-- @module links
local links = {}

local _links = {}

_G.links = _links

local settings = require("settings")
local boot = require("boot")
local log = iot.logger("links")

local types = {}

--- 注册链接
function links.register(name, clazz)
    types[name] = clazz
end

--- 创建链接
function links.create(opts)
    log.info("create", iot.json_encode(opts))

    local clazz = types[opts.type]
    if not clazz then
        return false, "未知链接类型" .. opts.type
    end

    local link = clazz:new(opts)
    if opts.id and #opts.id > 0 then
        -- 注册到全局
        _links[opts.id] = link
    end
    if opts.name and #opts.name > 0 then
        _links[opts.name] = link
    end

    local ret, info = link:open()
    if not ret then
        return false, info
    end

    return true, link
end

--- 加载链接
function links.open()
    log.info("load")
    local lnks = {}

    local cms = settings.links
    for k, v in ipairs(cms) do
        local ret, info = links.create(v)
        if not ret then
            log.error(info)
        else
            table.insert(lnks, info)
        end
    end

    return true, lnks
end

--- 关闭连接
function links.close()
    for i, s in pairs(_links) do
        if type(s) == "table" then
            pcall(s.close, s)
        end
    end
end

--- 所有连接
function links.links()
    return _links
end

--- 获取连接
function links.get(id)
    return _links[id]
end

links.deps = {"settings"}

settings.register("links", {})
boot.register("links", links)

return links
