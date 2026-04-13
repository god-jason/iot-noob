--- 桥接 连接绑定
-- @module bridge
local bridge = {}

local log = iot.logger("bridge")

local boot = require("boot")

local database = require("database")
local links = require("links")

local _bridges = {}

--- 设备镜像
-- @module Bridge
local Bridge = require("utils").class()

function Bridge:init()
    self.sub1 = self.l1:on("data", function(data)
        self.l2:write(data)
    end)
    self.sub2 = self.l2:on("data", function(data)
        self.l1:write(data)
    end)
end

--- 关闭
function Bridge:close()
    if self.sub1 then
        self.sub1()
        self.sub1 = nil
    end
    if self.sub2 then
        self.sub2()
        self.sub2 = nil
    end
end

--- 创建镜像
function bridge.create(b)
    log.info("create", iot.json_encode(b))

    b.l1 = links.get(b.link1)
    if not b.l1 then
        return false, "找不到第一个设备"
    end

    b.l2 = links.get(b.link2)
    if not b.l2 then
        return false, "找不到第二个设备"
    end

    local s = Bridge:new(b)
    _bridges[s.id] = s

    return true, s
end

--- 加载镜像
function bridge.open()
    local bs = database.find("bridge")
    for i, b in ipairs(bs) do
        local ret, info = bridge.create(b)
        if not ret then
            log.error("mirror:", b.link1, b.link2, " open error:", info)
        end
    end
    return true
end

--- 关闭镜像
function bridge.close()
    for i, s in pairs(_bridges) do
        s:close()
    end
    _bridges = {}
end

boot.register("bridge", bridge, "links", "hub")
