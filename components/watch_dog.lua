--- 组件 外部看门狗
-- @module watch_dog
local WatchDog = {}
WatchDog.__index = WatchDog

require("components").register("watch_dog", WatchDog)

local log = iot.logger("watch_dog")

--- 初始化
function WatchDog:new(opts)
    opts = opts or {}
    local watch_dog = setmetatable({
        pin = opts.pin,
        interval = opts.interval or 30, -- 喂狗间隔，秒
        high_time = opts.high_time or 400, -- 高电平持续时间，毫秒
        close_time = opts.close_time or 700, -- 关闭时高电平持续时间，毫秒
        timer = nil
    }, WatchDog)
    watch_dog:init()
    return watch_dog
end

function WatchDog:init()
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
