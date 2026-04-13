--- 集线器 串口复用
-- @module hub
local hub = {}

local log = iot.logger("hub")
local boot = require("boot")
local settings = require("settings")
local database = require("database")
local links = require("links")

local _hubs = {}

--- 集线器虚拟连接，继承Link
local HubLink = require("utils").class(require("event"))

function HubLink:open()
    self.hub = _hubs[self.hub_id]
    if not self.hub then
        return false, "集线器未打开"
    end
    return true
end

function HubLink:write(data)
    -- 写数据到集线器
    return self.hub:write(data, self)
end

--- 集线器连接，继承Link
local Hub = require("utils").class(require("event"))

function Hub:init()
    self.using = false
    self.listener = nil
end

function Hub:open()
    log.info("打开集线器", self.name or self.id, "链接", self.link_id)

    self.link = links.get(self.link_id)
    if not self.link then
        return false, "连接未打开" .. self.link_id
    end

    self.cancel = self.link:on("data", function(data)
        self.using = false -- 收到数据就解锁

        -- 发送
        self:emit("data", data)

        -- 转发到虚拟连接
        if self.child then
            self.child:emit("data", data)
        end

        if self.timer then
            iot.clearTimeout(self.timer)
            self.timer = nil
        end
    end)

    return true
end

function Hub:close()
    if self.cancel then
        self.cancel()
        self.cancel = nil
    end
    self.listener = nil
    self.using = false
    self.child = nil
end

function Hub:write(data, link)
    if not self.link then
        return false, "连接未打开"
    end

    -- 重入锁，等待其他操作完成
    if self.child ~= link then
        while self.using do
            log.info("集线器等待上一个数据处理完成", self.id, link.id)
            iot.sleep(200)
        end
    end

    self.using = true
    self.child = link

    local ret, info = self.link:write(data)
    if not ret then
        return false, info
    end

    -- 设置超时，防止数据处理失败导致阻塞
    if self.timer then
        iot.clearTimeout(self.timer)
    end
    self.timer = iot.setTimeout(function()
        self.using = false
        self.timer = nil
    end, self.timeout or 1000)

    return true
end

function hub.open()
    local hubs = {
        hub1 = settings.hub1,
        hub2 = settings.hub2,
        hub3 = settings.hub3
    }

    for i, h in pairs(hubs) do
        if h and h.enable then
            local hb = Hub:new(h)
            local ret, info = hb:open()
            if not ret then
                log.error("连接集线器", i, h.name, " 出错:", info)
            else
                _hubs[i] = hb

                -- 加载虚拟连接
                local ls = database.find("hub_link", "hub_id", i)
                for i, l in ipairs(ls) do
                    local ret, link = links.create(HubLink, l)
                    if not ret then
                        log.error("连接虚拟连接", i, l.name, " 出错:", link)
                    else
                        link.hub = hb
                    end
                end
            end

        end
    end
    return true
end

function hub.close()
    for k, hb in pairs(_hubs) do
        hb:close()
    end
    _hubs = {}
end

boot.register("hub", hub, "settings", "serials")

settings.register("hub1")
settings.register("hub2")
settings.register("hub3")

return hub
