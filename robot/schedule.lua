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
    components.rtc:read()

    -- TODO 加载定时任务

    return true
end

--- 关闭
function schedule.close()
    
    return true
end

schedule.deps = {"components", "settings"}

-- 注册
boot.register("schedule", schedule)

return schedule
