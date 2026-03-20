local mirrors = {}

local log = iot.logger("mirror")

local boot = require("boot")

local settings = require("settings")
local Mirror = require("mirror")
local master = require("master")

local _mirrors = {}

-- 查找设备
local function find_device(id)
    -- 未传值，则使用网关设备
    if not id or id == "" or master.device.id == id then
        return master.device
    end
    return devices[id]
end


--- 创建镜像
function mirrors.create(mirror)
    log.info("create", iot.json_encode(mirror))

    local dev1 = find_device(mirror.device1)
    if not dev1 then
        return false, "找不到第一个设备"
    end

    local dev2 = find_device(mirror.device2)
    if not dev2 then
        return false, "找不到第二个设备"
    end

    local s = Mirror:new(dev1, dev2)
    table.insert(_mirrors, s)

    return true, s
end

--- 加载镜像
function mirrors.open()
    local ss = settings.mirrors or {}
    for i, s in ipairs(ss) do
        local ret, info = mirrors.create(s)
        if not ret then
            log.error("mirror:", s.device1, s.device2, " open error:", info)
        end
    end
    return true
end

--- 关闭镜像
function mirrors.close()
    for i, s in ipairs(_mirrors) do
        s:close()
    end
    _mirrors = {}
end

mirrors.deps = {"devices", "master", "settings"}

settings.register("mirrors", {})

boot.register("mirrors", mirrors)