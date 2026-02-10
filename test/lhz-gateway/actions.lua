local actions = {}

local tag = "actions"

local database = require "database"
local gateway = require "gateway"

actions.watching = false

local watcher = 0

function actions.watch(data)
    log.info(tag, "查看")
    watcher = watcher + 1

    actions.watching = true

    local w = watcher

    local tm = data.value or 60000
    iot.setTimeout(function()
        -- log.info(tag, "watch timeout", w, watcher)
        -- 只在最后一个定时结束时，结束监听
        if w == watcher then
            actions.watching = false
        end
    end, tm)

    return true
end

-- 清除数据
function actions.reset()
    log.info(tag, "清除数据")
    database.clear("device")
    database.clear("model")

    iot.setTimeout(iot.reboot, 2000)
    return true
end

-- 重启设备
function actions.reboot()
    iot.emit("device_log", "重启设备")
    rtos.reboot()
    return true
end

function actions.fan(data)
    local dev = gateway.get_device_instanse("num002")
    if data.value then
        dev:set("fan_control", 1)
    else
        dev:set("fan_control", 0)
    end
end

function actions.jump(data)
    local dev = gateway.get_device_instanse("num002")
    if data.value then
        dev:set("jump_control", 1)
    else
        dev:set("jump_control", 0)
    end
end


return actions
