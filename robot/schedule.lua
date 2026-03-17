--- 定时任务
-- @module schedule
local schedule = {}

local log = iot.logger("schedule")

local configs = require("configs")
local boot = require("boot")
local cron = require("cron")

-- 自动校时，更新计划任务
iot.on("IP_READY", socket.sntp)

-- NTP更新成功
iot.on("NTP_UPDATE", function()

    -- 更新到时钟芯片
    if components.rtc then
        components.rtc:write()
    end

    -- 重新检查到期
    cron.execute()
end)

-- RTC更新成功
iot.on("RTC_OK", function()
    -- 重新检查到期
    cron.execute()
end)

--- 打开
function schedule.open()
    log.info("open")

    -- 读取RTC时钟
    if components.rtc then
        components.rtc:read()
    end

    -- TODO 加载定时任务

    return true
end

local ids = {}

-- 定时任务 时钟模式 00:00
function schedule.clock(time, fn)
    local ret, id = cron.clock(time, fn)
    if not ret then
        return false, id
    end

    -- 保存计划ID
    table.insert(ids, id)

    return true
end

-- 定时任务 linux crontab格式
function schedule.start(crontab, fn)
    local ret, id = cron.start(crontab, fn)
    if not ret then
        return false, id
    end

    -- 保存计划ID
    table.insert(ids, id)

    return true
end

-- 取消定时任务
function schedule.clear()
    for i, v in ipairs(ids) do
        cron.stop(v)
    end
    ids = {}
end

--- 关闭
function schedule.close()

    return true
end

schedule.deps = {"components", "settings"}

-- 注册
boot.register("schedule", schedule)

return schedule
