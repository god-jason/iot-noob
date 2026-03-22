--- 组件 外部看门狗
-- @module watch_dog
local WatchDog = require("utils").class(require("component"))

require("components").register("watch_dog", WatchDog)

local log = iot.logger("WatchDog")

--- 初始化
function WatchDog:init(opts)
    self.pin = self.pin
    self.interval = self.interval or 30 -- 喂狗间隔，秒
    self.high_time = self.high_time or 400 -- 高电平持续时间，毫秒
    self.close_time = self.close_time or 700 -- 关闭时高电平持续时间，毫秒
    self.timer = nil
    self.gpio = iot.gpio(self.pin)
    self.gpio:set(0)

    -- 定时投喂
    self.timer = iot.setInterval(function()
        self:feed()
    end, self.interval * 1000)
end

-- 手动喂狗，一般不用
function WatchDog:feed()
    self.gpio:set(1)

    iot.setTimeout(function()
        self.gpio:set(0)
    end, self.high_time)
end

-- 关闭
function WatchDog:close()
    iot.clearInterval(self.timer)

    self.gpio:set(1)
    iot.setTimeout(function()
        self.gpio:set(0)
    end, self.close_time)
end
