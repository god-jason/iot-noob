-- @module clock
local clock = {}

local log = iot.logger("clock")

-- 自增ID
local increment = 1
-- 所有任务
local jobs = {}
-- 定时器句柄
local next_timer

-- 计算下一次触发时间（每天固定时分秒）
local function calc_next(h, m, s)
    local now = os.time()
    local t = os.date("*t", now)
    t.hour = h
    t.min = m
    t.sec = s

    local next_time = os.time(t)
    if next_time <= now then
        -- 如果今天已经过了，则定到明天
        next_time = next_time + 24 * 3600
    end
    return next_time
end

-- 执行任务
local function execute()
    if next_timer then
        iot.clearTimeout(next_timer)
        next_timer = nil
    end

    local now = os.time()
    local nearest = nil

    for id, job in pairs(jobs) do
        if now >= job.next then
            -- 异步执行回调
            iot.start(job.callback)
            -- 更新下一次执行时间
            job.next = calc_next(job.hour, job.min, job.sec)
        end

        if not nearest or job.next < nearest then
            nearest = job.next
        end
    end

    -- 安排下一次唤醒
    if nearest then
        local delay = nearest - now
        next_timer = iot.setTimeout(execute, delay * 1000 + 50) -- 加50ms保险
    end
end

--- 添加闹钟任务
-- @param time_str "HH:MM" 或 "HH:MM:SS"
-- @param callback function
-- @return boolean 成功与否
-- @return integer 任务ID
function clock.start(time_str, callback)
    local h, m, s = time_str:match("^(%d+):(%d+):?(%d*)$")
    if not h or not m then
        return false, "错误时间格式: " .. time_str
    end
    h = tonumber(h)
    m = tonumber(m)
    s = tonumber(s) or 0

    if h > 23 or m > 59 or s > 59 then
        return false, "时间超出范围: " .. time_str
    end

    local id = increment
    increment = increment + 1

    local next_time = calc_next(h, m, s)

    jobs[id] = {
        hour = h,
        min = m,
        sec = s,
        callback = callback,
        next = next_time
    }

    execute() -- 立即更新定时器

    return true, id
end

--- 删除闹钟任务
-- @param id integer
function clock.stop(id)
    if jobs[id] then
        jobs[id] = nil
    end
end

return clock