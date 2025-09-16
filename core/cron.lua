--- 定时任务相关
--- @module "cron"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.18

--- 定时任务相关
-- @module cron
local cron = {}

local tag = "cron"

local increment = 1 -- 自增ID

-- 所有任务
local jobs = {}

local function parse_item(str)
    -- log.info(tag, "parse_item()", str)
    local item = {}

    -- 全部
    if str == "*" then
        item.every = true
        return true, item
    end

    -- 每
    if string.startsWith(str, "*/") then
        local mod = string.sub(str, 3)
        item.mod = tonumber(mod)
        return true, item
    end

    -- 散列
    local is = string.split(str, ",")
    for _, s in ipairs(is) do
        local ss = string.split(s, "-")
        if #ss == 1 then
            -- table.insert(item, tonumber(s), true)
            item[s] = true
        elseif #ss == 2 then
            for j = tonumber(ss[1]), tonumber(ss[2]), 1 do
                -- table.insert(item, j, true)
                item[tostring(j)] = true
            end
        else
            return false
        end
    end

    return true, item
end

local function parse(crontab)
    log.info(tag, "parse()", crontab)
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

    local ret

    local items = {"sec", "min", "hour", "day", "month", "wday"}
    for i, f in ipairs(items) do
        ret, job[f] = parse_item(cs[i])
        if not ret then
            return false
        end
    end

    log.info(tag, "parse()", json.encode(job))

    return true, job
end

local function calc_wday(time, field)
    local added = false
    local wday = time.wday
    if field.every then
        added = false
    elseif field.mod then
        while wday % field.mod ~= 0 do
            wday = wday + 1
            time.day = time.day + 1

            if wday > 7 then
                wday = 1
            end
            added = true
        end
    else
        while not field[tostring(wday)] do
            -- log.info(tag, "calc_next dot", f, tm[f])
            wday = wday + 1
            time.day = time.day + 1

            -- 1-7 日一二三四五六
            if wday > 7 then
                wday = 1
            end
            added = true
        end
    end
    return added
end

local function calc_field(time, field, key, upper, min, max)
    local added = false
    -- 跳过年，计算 月 日 时 分 秒
    if field.every then
        -- log.info(tag, "calc_next every", f)
        -- 所有，不用计算了
        return false
    elseif field.mod then
        -- 计算模
        -- log.info(tag, "calc_next mod", f)
        while time[key] % field.mod ~= 0 do
            -- log.info(tag, "calc_next mod", f, tm[f])
            time[key] = time[key] + 1

            -- 越界
            if time[key] > max then
                time[upper] = time[upper] + 1 -- 上级时间单位进一
                time[key] = min -- 从0开始
            end
            added = true
        end
    else
        -- 计算散列
        -- log.info(tag, "calc_next dot", f)
        while not field[tostring(time[key])] do
            -- log.info(tag, "calc_next dot", f, tm[f])
            time[key] = time[key] + 1

            -- 越界
            if time[key] > max then
                time[upper] = time[upper] + 1 -- 上级时间单位进一
                time[key] = min -- 从0开始
            end
            added = true
        end
    end
    return added
end

local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 31, 30}
local function get_month_days(time)
    local d = days[time.month]
    if d == 28 then
        if time.year % 4 == 0 then
            if time.year % 100 == 0 then
                if time.year % 400 == 0 then
                    d = d + 1
                end
            else
                d = d + 1
            end
        end
    end
    return d
end

local function calc_next(job, now)
    -- log.info(tag, "calc_next()", job.crontab)

    -- 复制当前时间，并延后1秒再执行
    local next = now + 1

    local added = true

    -- 迭代计算下一个时间
    while added do

        local tm = os.date("!*t", next)
        -- log.info(tag, "next begin", json.encode(tm))

        -- 先计算星期
        added = calc_wday(tm, job.wday) or calc_field(tm, job.month, "month", "year", 1, 12) or
                    calc_field(tm, job.day, "day", "month", 1, get_month_days(tm)) or
                    calc_field(tm, job.hour, "hour", "day", 0, 23) or calc_field(tm, job.min, "min", "hour", 0, 59) or
                    calc_field(tm, job.sec, "sec", "min", 0, 59)
        -- log.info(tag, "next end", json.encode(tm))

        -- 重新计算时间
        if added then
            next = os.time(tm)
            -- log.info(tag, "calc_next added")
        end
    end

    job.next = next

    log.info(tag, job.crontab, "next is", os.date("%y/%m/%d, %H:%M:%S", next))
end

local next_time

local function execute()
    log.info(tag, "execute()")

    -- 找到下一个执行时间点，但后
    local now = os.time()
    local next
    for _, job in pairs(jobs) do
        if not job.next then
            calc_next(job, now)
        elseif job.next <= now then
            for _, cb in pairs(job.callbacks) do
                -- 异步执行(不知道有没有数量限制，会不会影响性能)
                sys.taskInit(cb)
            end
            calc_next(job, now)
        end

        if next == nil or job.next < next then
            next = job.next
        end
    end

    -- 下次唤醒
    if next ~= nil and next > now then
        if not next_time or next_time ~= next then
            next_time = next
            log.info(tag, "wait", (next - now))
            sys.timerStart(execute, (next - now) * 1000)
        end
    end
end

--- 创建计划任务
---@param crontab string Linux crontab格式，支持到秒，[*] * * * * *
---@param callback function
---@return boolean 成功与否
---@return integer 任务ID
function cron.start(crontab, callback)
    crontab = string.trim(crontab) -- 删除前后空白

    -- 重复规则
    local job = jobs[crontab]
    if job ~= nil then
        job.count = job.count + 1
        -- table.insert(job.callbacks, increment, callback)
        job.callbacks[increment] = callback
        increment = increment + 1
        return true, increment - 1
    end

    -- 新规则
    local ret

    ret, job = parse(crontab)
    if not ret then
        log.error(tag, "parse failed", crontab)
        return false
    end
    jobs[crontab] = job

    job.crontab = crontab
    job.count = 1
    job.callbacks = {
        [increment] = callback
    }
    increment = increment + 1

    execute() -- 强制执行一次

    return true, increment - 1
end

--- 删除任务
---@param id integer
function cron.stop(id)
    for k, job in pairs(jobs) do
        if job.callbacks[id] ~= nil then
            if job.count <= 1 then
                table.remove(jobs, k)
                break
            end
            table.remove(job.callbacks, id)
            job.count = job.count - 1
            break
        end
    end
end

return cron
