--- 定时任务相关
--- @module "cron"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.18
local tag = "cron"
local cron = {}

local increment = 1 -- 自增ID

-- 所有任务
local jobs = {}

local function parse_item(str)
    local item = {}

    -- 全部
    if str == "*" then
        item.every = true
        return true, item
    end

    -- 每
    if sring.startWith(str, "*/") then
        local mod = string.sub(str, 3)
        item.mod = tonumber(mod)
        return true, item
    end

    -- 散列
    local is = string.split(str, ",")
    for i, s in ipairs(is) do
        local ss = string.split(s, "-")
        if #ss == 1 then
            table.insert(item, tonumber(s), true)
        elseif #ss == 2 then
            for j = tonumber(ss[1]), tonumber(ss[2]), 1 do
                table.insert(item, j, true)
            end
        else
            return false
        end
    end

    return true, item
end

local function parse(crontab)
    local job = {}

    crontab = string.trim(crontab)
    local cs = string.split(crontab, " ")
    if #cs < 5 or #cs > 6 then
        return false
    end

    -- 支持到秒
    if #cs == 5 then
        table.insert(cs, 1, "0")
    end

    local ret = false

    local items = {"sec", "min", "hour", "day", "month", "wday"}
    for i, f in ipairs(items) do
        ret, job[i] = parse_item(cs[i])
        if not ret then
            return false
        end
    end

    return true, job
end

local function calc_next(job, now)
    -- 复制当前时间
    local next = now

    local items = {"month", "day", "hour", "min", "sec"}

    local added = true

    -- 迭代计算下一个时间
    while added do
        added = false
        local tm = os.date("*t", next)
        for i, f in ipairs(items) do
            if job[f].every then
                -- 所有，不用计算了
            elseif job[f].mod then
                while tm[f] % job[f].mod ~= 0 do
                    tm[f] = tm[f] + 1
                    added = true
                end
            else
                while not job[f].values[tm[f]] do
                    tm[f] = tm[f] + 1
                    added = true
                end
            end

            -- 重新计算时间
            if added then
                next = os.time(tm)
            end
        end
    end

    job.next = next
end

local next_time

local function execute()
    -- 找到下一个执行时间点，但后
    local now = os.time()
    local next = now + 365 * 24 * 3600
    for c, job in pairs(jobs) do
        if not job.next then
            calc_next(job, now)
        elseif job.next <= now then
            calc_next(job, now)
            for id, cb in pairs(job.callbacks) do
                -- 异步执行
                sys.taskInit(cb)
            end
        end

        if job.next < next then
            next = job.next
        end
    end

    -- 下次唤醒
    if not next_time or next_time ~= next then
        next_time = next
        sys.timerStart(execute, (next - now) * 1000)
    end
end

function cron.start(crontab, callback)
    local job = jobs[crontab]
    if job ~= nil then
        job.count = job.count + 1
        table.insert(job.callbacks, increment, callback)
        increment = increment + 1
        return true, increment - 1
    end

    local ret, job = parse(crontab)
    if not ret then
        log.info(tag, "parse failed", crontab)
        return false
    end
    jobs[crontab] = job

    job.count = 1
    job.callbacks = {[increment] = callback}
    increment = increment + 1

    execute() -- 强制执行一次

    return true, increment - 1
end

function cron.stop(id)
    for k, job in pairs(jobs) do
        if job.callbacks[id] ~= nil then
            if job.count <= 1 then
                table.remove(jobs, k)
                break
            end
            table.remove(job.callbacks, id)
            job.count = job.count -1    
            break
        end
    end
end

return cron
