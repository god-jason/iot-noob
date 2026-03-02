local actions = {}

local log = iot.logger("actions")

local settings = require "settings"
local database = require "database"

-- 注册响应
function actions.register(name, fn)
    actions[name] = fn
end

actions.watching = false

local watcher = 0

function actions.watch(data)
    log.info("查看")
    watcher = watcher + 1

    actions.watching = true

    local w = watcher

    local tm = data.value or 60000
    iot.setTimeout(function()
        -- log.info("watch timeout", w, watcher)
        -- 只在最后一个定时结束时，结束监听
        if w == watcher then
            actions.watching = false
        end
    end, tm)
end

-- 清除数据
function actions.reset()
    log.info("清除数据")
    database.clear("device")
    database.clear("model")
    settings.reset()
    iot.setTimeout(iot.reboot, 2000)
    return true
end

-- 重启设备
function actions.reboot()
    iot.emit("device_log", "重启设备")
    iot.setTimeout(iot.reboot, 2000)
    return true
end

function actions.upgrade(data)
    iot.emit("device_log", "升级设备" .. data.version)
    iot.upgrade(data.url)
end

return actions
