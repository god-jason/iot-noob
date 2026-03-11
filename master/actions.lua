local actions = {}

local log = iot.logger("actions")

local settings = require "settings"
local database = require "database"

actions.watching = false

local watcher = 0

function actions.watch(data)
    log.info("查看")
    watcher = watcher + 1

    actions.watching = true

    local w = watcher

    local tm = (data.value or 60) * 1000
    iot.setTimeout(function()
        -- 只在最后一个定时结束时，结束监听
        if w == watcher then
            actions.watching = false
        end
    end, tm)
    return true
end

-- 清除数据
function actions.reset()
    iot.emit("device_log", "恢复出厂设置")
    -- 删除所有文件，恢复出厂设置
    iot.walk("/", function(fn)
        log.info("remove", fn)
        os.remove(fn)
    end)
    iot.setTimeout(iot.reboot, 1000)
    return true
end

-- 重启设备
function actions.reboot()
    iot.emit("device_log", "重启设备")
    iot.setTimeout(iot.reboot, 2000)
    return true
end

function actions.upgrade(data)
    iot.emit("device_log", "升级设备" .. (data.version or ''))
    iot.upgrade(data.url)
    return true
end

return actions
