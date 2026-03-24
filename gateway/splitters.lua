--- 分线器，二主一从，可以桥接两个串口，从中截取数据
-- @module splitters
local splitters = {}

local log = iot.logger("splitter")
local boot = require("boot")
local settings = require("settings")

local _splitters = {}

--- 三通连接，继承Link
-- @module Splitter
local Splitter = require("utils").class(require("event"))

-- 初始化
function Splitter:init()
    self.name = self.name or "三通" .. self.port
    self.type = "三通"
    self.buffer = ""
    self.running = false
end

-- 打开，
function Splitter:open()
    self._master = links[self.master]
    if not self._master then
        return false, "主连接未打开"
    end

    self._slave = links[self.slave]
    if not self._slave then
        return false, "从连接未打开"
    end

    self.sub1 = self._master:on("data", function(data)
        if self.running then
            if #self.buffer < 1024 then
                self.buffer = self.buffer .. data
            else
                log.error("主连接数据太多，丢弃", data:toHex())
            end
        else
            self._slave:write(data)
        end
    end)
    self.sub2 = self._slave:on("data", function(data)
        if self.running then
            self:emit("data", data)
        else
            self._master:write(data)
        end
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

--- 加载镜像
function splitters.open()
    local ts = settings.splitters or {}
    for i, t in ipairs(ts) do
        local ret, info = splitters.create(t)
        if not ret then
            log.error("连接三通", t.master, t.slave, t.name, " 出错:", info)
        else
            table.insert(_splitters, info)
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

settings.register("splitters", {})

boot.register("splitters", splitters, "serials", "sockets")
