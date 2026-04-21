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

        -- 延时解锁，避免散包的问题
        if self.unlockTimer then
            iot.clearTimeout(self.unlockTimer)
        end
        self.unlockTimer = iot.setTimeout(function()
            self.using = false -- 不能收到数据就立马解锁
            self.unlockTimer = nil
        end, self.timeout or 500)

        -- 发送
        self:emit("data", data)

        -- 转发到虚拟连接
        if self.child then
            -- log.info("分发数据", self.id or self.name, "--->", self.child.name, self.child.id, "数据长度", #data)
            self.child:emit("data", data)
        end

        if self.lockTimer then
            iot.clearTimeout(self.lockTimer)
            self.lockTimer = nil
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
    -- log.info("写入数据", self.id or self.name, "数据长度", #data, "<---", link.name, link.id)

    -- 重入锁，等待其他操作完成
    if self.child ~= link then
        while self.using do
            log.info("等待上一个数据处理完成", self.id, self.child.id)
            iot.sleep(self.timeout or 500)
        end
    end

    self.using = true
    self.child = link

    local ret, info = self.link:write(data)
    if not ret then
        return false, info
    end

    -- 设置超时，防止数据处理失败导致阻塞
    if self.lockTimer then
        iot.clearTimeout(self.lockTimer)
    end
    self.lockTimer = iot.setTimeout(function()
        self.using = false
        self.lockTimer = nil
    end, self.timeout or 500)

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
            h.id = h.id or i -- 如果没有id，使用键名作为id

            local hb = Hub:new(h)
            local ret, info = hb:open()
            if not ret then
                log.error("连接集线器", i, h.name, " 出错:", info)
            else
                _hubs[i] = hb

                -- 加载虚拟连接
                local ls = database.find("hub_link", "hub_id", i)
                for j, l in ipairs(ls) do
                    local ret2, link = links.create(HubLink, l)
                    if not ret2 then
                        log.error("连接虚拟连接", j, l.name, " 出错:", link)
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
