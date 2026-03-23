--- 二主一从，可以桥接两个串口，从中截取数据
-- @module splitters
local splitters = {}

local log = iot.logger("splitter")
local boot = require("boot")
local settings = require("settings")
local protocols = require("protocols")

local _splitters = {}

local Splitter = require("utils").class(require("event"))

-- 初始化
function Splitter:init()
    self.buffer = ""
    self.running = false
end

-- 打开，
function Splitter:open()
    self.sub1 = self.master:on("data", function(data)
        if self.running then
            if #self.buffer < 1024 then
                self.buffer = self.buffer .. data
            end
            return
        end

        self.slave:write(data)
    end)
    self.sub2 = self.slave:on("data", function(data)
        if self.running then
            self:emit("data", data)
            return
        end

        self.master:write(data)
    end)
    return true
end

--- 关闭
function Splitter:close()
    if self.sub1 then
        self.sub1()
        self.sub1 = nil
    end
    if self.sub2 then
        self.sub2()
        self.sub2 = nil
    end
    return true
end

-- 发送数据，到从设备
function Splitter:write(data)
    self.running = true
    self.slave:write(data)

    -- 延时关闭通道 默认100ms
    if self.timer then
        iot.clearTimeout(self.timer)
    end
    self.timer = iot.setTimeout(function()
        self.timer = nil
        self.running = false

        if #self.buffer > 0 then
            self.slave:write(data)
            self.buffer = ""
        end
    end, self.timeout or 100)

    return true
end

--- 创建镜像
function splitters.create(t)
    log.info("create", iot.json_encode(t))

    local master = links[t.master]
    if not master then
        return false, "找不到主连接"
    end

    local slave = links[t.slave]
    if not slave then
        return false, "找不到从连接"
    end

    -- 初始化实例
    local splitter = Splitter:new({
        id = t.id,
        master = master,
        slave = slave,
        timeout = t.timeout
    })
    table.insert(_splitters, splitter)

    -- 注册到全局
    links[t.id or "splitter"] = splitter

    -- 直接打开了
    splitter:open()

    -- 打开协议
    if splitter.protocol and #splitter.protocol > 0 then
        -- 创建协议
        local ret, instanse = protocols.create(splitter, splitter.protocol, splitter.protocol_options or {})
        if not ret then
            return false, instanse
        end

        -- 打开协议
        local ret, info = iot.xcall(instanse.open, instanse)
        if not ret then
            return false, info
        end

        -- 协议的实例，比如Modbus主站
        splitter.protocol_instance = instanse
    end

    return true, splitter
end

--- 加载镜像
function splitters.open()
    local ts = settings.splitters or {}
    for i, t in ipairs(ts) do
        local ret, info = splitters.create(t)
        if not ret then
            log.error("连接三通", t.master, t.slave, " 出错:", info)
        end
    end
    return true
end

--- 关闭镜像
function splitters.close()
    for i, s in ipairs(_splitters) do
        s:close()
    end
    _splitters = {}
end

splitters.deps = {"links", "settings"}

settings.register("splitters", {})

boot.register("splitter", splitters)
