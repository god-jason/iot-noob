--- 定时任务
-- @module schedule
local schedule = {}

local log = iot.logger("schedule")

local agent = require("agent")
local actions = agent.actions()

local configs = require("configs")
local boot = require("boot")
local cron = require("cron")
local database = require("database")

local jobs = {}

-- 定时任务 时钟模式 00:00
function schedule.create(job)
    -- 停止上次定时
    if jobs[job.id] then
        cron.stop(jobs[job.id])
    end

    local ret, id = cron.clock(job.time, function()
        schedule.execute(job.id)
    end, job.weekdays)
    if not ret then
        return false, id
    end

    -- 保存计划ID
    jobs[job.id] = id
    return true
end

--- 停用任务（包括禁用）
function schedule.stop(id)
    if jobs[id] then
        cron.stop(jobs[id])
        return true
    end
    return false, "未启用的任务"
end

--- 执行任务
function schedule.execute(id)
    local job = database.get("job", id)
    if not job then
        return false, "任务不存在"
    end
    return agent.execute(job.action, job.data)
end

-- 注册到命令，方便远程控制
function actions.job_create(data)
    return schedule.create(data)
end
function actions.job_stop(data)
    return schedule.stop(data.id)
end
function actions.job_execute(data)
    return schedule.execute(data.id)
end

--- 加载
function schedule.open()
    log.info("open")

    -- 读取RTC时钟
    if components.rtc then
        components.rtc:read()
    end

    -- 24个小时，同步一次时间
    -- iot.setInterval(socket.sntp, 24 * 3600)
    cron.clock("01:00", socket.sntp) -- 同步时间提前了，会再次重复执行

    local ss = database.find("job")
    for i, s in ipairs(ss) do
        if not s.disabled then
            local ret, info = schedule.create(s)
            if not ret then
                log.error(s.id, " open error:", info)
            end
        end
    end

    return true
end

--- 关闭
function schedule.close()
    for i, v in pairs(jobs) do
        cron.stop(v)
    end
    jobs = {}
end

-- 注册
boot.register("schedule", schedule, "components", "settings")

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

-- RTC读取成功
iot.on("RTC_OK", function()
    -- 重新检查到期
    cron.execute()
end)

return schedule
