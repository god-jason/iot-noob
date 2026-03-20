local link_bridge = {}

local log = iot.logger("link_bridge")

local boot = require("boot")

local settings = require("settings")
local master = require("master")

local _bridges = {}

--- 连接镜像
-- @module LinkBridge
local LinkBridge = {}
LinkBridge.__index = LinkBridge

function LinkBridge:new(link1, link2)
    local obj = setmetatable({
        link1 = link1,
        link2 = link2,
        running = false,
    }, LinkBridge)
    return obj
end

function LinkBridge:open()

    -- 读取当前数据并转发
    iot.start(function()
        while self.running do
            self.link1:wait(1000)
            local ret, data = self.link1:read()
            if ret then
                log.info("from link1 to link2", data:toHex())
                self.link2:write(data)
            end
        end
    end)

    -- 读取对方数据并写入
    iot.start(function()
        while self.running do
            self.link2:wait(1000)
            local ret, data = self.link2:read()
            if ret then
                log.info("from link2 to link1", data:toHex())
                self.link1:write(data)
            end
        end
    end)

end

--- 关闭
function LinkBridge:close()
    self.running = false
end

--- 创建镜像
function link_bridge.create(mirror)
    log.info("create", iot.json_encode(mirror))

    local link1 = links[mirror.link1]
    if not link1 then
        return false, "找不到第一个连接"
    end

    local link2 = links[mirror.link2]
    if not link2 then
        return false, "找不到第二个连接"
    end

    local s = LinkBridge:new(link1, link2)
    table.insert(_bridges, s)

    return true, s
end

--- 加载镜像
function link_bridge.open()
    local ss = settings.link_bridge or {}
    for i, s in ipairs(ss) do
        local ret, info = link_bridge.create(s)
        if not ret then
            log.error("mirror:", s.link1, s.link2, " open error:", info)
        end
    end
    return true
end

--- 关闭镜像
function link_bridge.close()
    for i, s in ipairs(_bridges) do
        s:close()
    end
    _bridges = {}
end

link_bridge.deps = {"links", "master", "settings"}

settings.register("link_bridge", {})

boot.register("link_bridge", link_bridge)