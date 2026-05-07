--- 桥接 连接绑定
-- @module bridge
local bridge = {}

local log = iot.logger("bridge")

local boot = require("boot")

local database = require("database")
local links = require("links")

local _bridges = {}

--- 桥接
-- @module Bridge
local Bridge = require("utils").class()

function Bridge:init()
    self.topic = "BRIDGE_DATA_" .. self.id

    self.sub1 = self.l1:on("data", function(data)
        iot.emit(self.topic, {
            link = self.l2,
            data = data
        })
    end)
    self.sub2 = self.l2:on("data", function(data)
        iot.emit(self.topic, {
            link = self.l1,
            data = data
        })
    end)

    self.running = true
    iot.start(function()
        while self.running do
            local ret, data = iot.wait(self.topic, 5000)
            if ret and data then
                data.link:write(data.data)
            end
        end
    end)
end

--- 关闭
function Bridge:close()
    self.running = false
    iot.emit(self.topic) -- 立即结束等待

    if self.sub1 then
        self.sub1()
        self.sub1 = nil
    end
    if self.sub2 then
        self.sub2()
        self.sub2 = nil
    end
end

--- 创建桥接
function bridge.create(b)
    log.info("create", iot.json_encode(b))

    b.l1 = links.get(b.link1)
    if not b.l1 then
        return false, "找不到第一个链接"
    end

    b.l2 = links.get(b.link2)
    if not b.l2 then
        return false, "找不到第二个链接"
    end

    local s = Bridge:new(b)
    _bridges[s.id] = s

    return true, s
end

--- 加载桥接
function bridge.open()
    local bs = database.find("bridge")
    for i, b in ipairs(bs) do
        local ret, info = bridge.create(b)
        if not ret then
            log.error("bridge:", b.link1, b.link2, " open error:", info)
        end
    end
    return true
end

--- 关闭桥接
function bridge.close()
    for i, s in pairs(_bridges) do
        s:close()
    end
    _bridges = {}
end

boot.register("bridge", bridge, "links", "hub")
