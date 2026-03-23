--- 连接三通，可以桥接两个串口，从中截取数据
-- @module tees
local tees = {}

local log = iot.logger("tees")
local boot = require("boot")
local settings = require("settings")

local _tees = {}

local Tee = require("utils").class(require("event"))

-- 初始化
function Tee:init()
    self.buffer = ""
    self.running = false
end

-- 打开，
function Tee:open()
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
function Tee:close()
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
function Tee:write(data)
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
function tees.create(t)
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
    local tee = Tee:new({
        id = t.id,
        master = master,
        slave = slave,
        timeout = t.timeout
    })
    table.insert(_tees, tee)

    -- 注册到全局
    links[t.id or "tee"] = tee

    -- 直接打开了
    tee:open()

    return true, tee
end

--- 加载镜像
function tees.open()
    local ts = settings.tees or {}
    for i, t in ipairs(ts) do
        local ret, info = tees.create(t)
        if not ret then
            log.error("连接三通", t.master, t.slave, " 出错:", info)
        end
    end
    return true
end

--- 关闭镜像
function tees.close()
    for i, s in ipairs(_tees) do
        s:close()
    end
    _tees = {}
end

tees.deps = {"links", "settings"}

settings.register("tees", {})

boot.register("tee", tees)
