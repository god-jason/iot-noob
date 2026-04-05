--- 定时任务相关
-- @module cron
local cron = {}

local log = iot.logger("cron")

local increment = 1 -- 自增ID

-- 所有任务
local jobs = {}

local function parse_item(str)
    -- log.info("parse_item()", str)
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
    log.info("parse()", crontab)
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

    log.info("parse()", iot.json_encode(job))

    return true, job
end

local function test_wday(time, field)
    local wday = time.wday
    if field.every then
        return true
    elseif field.mod then
        if wday % field.mod == 0 then
            return true
        end
    else
        if field[tostring(wday)] then
            return true
        end
    end
    return false
end

local function calc_field(time, field, key, upper, min, max)
    local added = false
    -- 跳过年，计算 月 日 时 分 秒
    if field.every then
        -- log.info("calc_next every", key)
        -- 所有，不用计算了
        return false
    elseif field.mod then
        -- 计算模
        -- log.info("calc_next mod", key)
        while time[key] % field.mod ~= 0 do
            -- log.info("calc_next mod", key, time[key])
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
        -- log.info("calc_next dot", f)
        while not field[tostring(time[key])] do
            -- log.info("calc_next dot", f, tm[f])
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
    log.info("calc_next()", job.crontab)

    -- 复制当前时间，并延后1秒再执行
    local next = now + 1

    local added = true

    -- 迭代计算下一个时间
    while added do

        -- local tm = os.date("!*t", next)
        local tm = os.date("*t", next)
        -- log.info("next begin", iot.json_encode(tm))

        -- 逐级计算累加时间
        -- added = calc_field(tm, job.sec, "sec", "min", 0, 59) or calc_field(tm, job.min, "min", "hour", 0, 59) or
        --             calc_field(tm, job.hour, "hour", "day", 0, 23) or
        --             calc_field(tm, job.day, "day", "month", 1, get_month_days(tm)) or
        --             calc_field(tm, job.month, "month", "year", 1, 12) or calc_wday(tm, job.wday)

        -- 先计算时分秒
        added = calc_field(tm, job.sec, "sec", "min", 0, 59) or calc_field(tm, job.min, "min", "hour", 0, 59) or
                    calc_field(tm, job.hour, "hour", "day", 0, 23)

        -- 计算日，星期（两个条件是或）
        if not added then
            -- 不满足星期的情况下才计算天
            local t = test_wday(tm, job.wday)
            if not t then
                added = calc_field(tm, job.day, "day", "month", 1, get_month_days(tm))
            end
        end

        -- 计算月份
        if not added then
            added = calc_field(tm, job.month, "month", "year", 1, 12)
        end

        -- log.info("next end", iot.json_encode(tm))

        -- 重新计算时间
        if added then
            next = os.time(tm) - 8 * 3600 -- 减去UTC 8小时 东八区
            -- log.info("calc_next added")
        end
    end

    job.next = next

    log.info(job.crontab, "next is", iot.json_encode(os.date("%Y-%m-%d %H:%M:%S", next)))
end

local next_timer

function cron.execute()
    log.info("execute 检查定时任务")

    -- 清空上一个定时器，避免无法启动
    if next_timer then
        log.info("execute 删除上个定时器")
        iot.clearTimeout(next_timer)
    end

    -- 找到下一个执行时间点，但后
    local now = os.time()
    local next
    for _, job in pairs(jobs) do
        if job ~= nil then
            if not job.next then
                calc_next(job, now)
            elseif job.next <= now then
                -- 超过1个小时，则丢弃（避免时间同步，系统日期有较大变化）
                if job.next > now - 3600 then
                    for _, cb in pairs(job.callbacks) do
                        -- 异步执行(不知道有没有数量限制，会不会影响性能)
                        iot.start(cb)
                    end
                end
                calc_next(job, now)
            end

            if next == nil or job.next < next then
                next = job.next
            end
        end
    end

    -- 下次唤醒
    if next ~= nil and next > now then
        log.info("下次唤醒时间", os.date("%Y-%m-%d %H:%M:%S", next))

        -- 每10分钟唤醒一次，避免NTP时间同步之后错误，导致长时间等待
        -- if next - now > 600 then
        --     next = now + 600
        -- end

        -- 改递减，避免next不一致
        while next - now > 600 do
            next = next - 600
        end

        -- 可以简化为
        -- next = now + (next - now) % 600

        -- 避免重复
        -- if not next_time or next_time ~= next then
        -- next_time = next
        log.info("wait", (next - now))
        -- 启动定时器
        next_timer = iot.setTimeout(function()
            next_timer = nil
            cron.execute()
        end, (next - now) * 1000 + 100) -- 加100ms，避免唤醒时间早于目标时间
    end
end

--- 创建计划任务
-- @param crontab string Linux crontab格式，支持到秒，[*] * * * * *
-- @param callback function
-- @return boolean 成功与否
-- @return integer 任务ID
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
        log.error("parse failed", crontab)
        return false, "解析错误" .. crontab
    end
    jobs[crontab] = job

    job.crontab = crontab
    job.count = 1
    job.callbacks = {
        [increment] = callback
    }
    increment = increment + 1

    cron.execute() -- 强制执行一次

    return true, increment - 1
end

--- 删除任务
-- @param id integer
function cron.stop(id)
    for k, job in pairs(jobs) do
        if job.callbacks[id] ~= nil then
            -- table.remove(job.callbacks, id)
            job.callbacks[id] = nil
            job.count = job.count - 1

            -- 清空定时
            if job.count < 1 then
                jobs[k] = nil
            end
            break
        end
    end
end

--- 创建时钟格式的计划任务
-- @param time 时间字符串: 06:00 或 06:00:00
-- @param callback function
-- @param wdays array 1-7 星期
-- @return boolean 成功与否
-- @return integer|string 任务ID或错误信息
function cron.clock(time, callback, wdays)
    local h, m, s = time:match("^(%d+):(%d+):?(%d*)$")

    if not h or not m then
        return false, "错误时间格式: " .. time
    end

    h = tonumber(h)
    m = tonumber(m)
    s = tonumber(s) or 0

    -- 范围检查
    if h > 23 or m > 59 or s > 59 then
        return false, "时间超出范围: " .. time
    end

    -- local crontab = string.format("%d %d %d * * *", s, m, h)
    local crontab = s .. " " .. m .. " " .. h .. " * * "
    if wdays and #wdays > 0 then
        crontab = crontab .. table.concat(wdays, ",")
    else
        crontab = crontab .. "*"
    end

    return cron.start(crontab, callback)
end

-- 每小时强制执行一次，避免出现定时器启动失败的问题
-- iot.setInterval(cron.execute, 3600)
-- iot.setInterval(cron.execute, 600) -- 改10分钟

return cron
