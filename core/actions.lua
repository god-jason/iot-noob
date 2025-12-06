local actions = {}

local tag = "actions"


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


return actions
