--- 定时任务相关
--- @module "cron"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.20
local tag = "cron"
local cron = {}

local increment = 1 -- 自增ID

local jobs = {} -- 所有任务

local job_test = {
    every = false,
    per = 5,
    values = {
        [1] = true,
        [2] = true,
        [3] = true
    },
    callback = nil
}

local function parse_item(str)
    local spec = {}

    -- 全部
    if str == "*" then
        spec.every = true
        return true, spec
    end

    -- 每
    if sring.startWith(str, "*/") then
        local per = string.sub(str, 3)
        spec.per = tonumber(per)
        return true, spec
    end

    -- 散列
    local is = string.split(str, ",")
    for i, s in ipairs(is) do
        local ss = string.split(s, "-")
        if #ss == 1 then
            table.insert(spec, tonumber(s), true)
        elseif #ss == 2 then
            for j = tonumber(ss[1]), tonumber(ss[2]), 1 do
                table.insert(spec, j, true)
            end
        else
            return false
        end
    end

    return true, spec
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
    ret, job.second = parse_item(cs[1])
    if not ret then
        return false
    end
    ret, job.minute = parse_item(cs[2])
    if not ret then
        return false
    end
    ret, job.hour = parse_item(cs[3])
    if not ret then
        return false
    end
    ret, job.day = parse_item(cs[4])
    if not ret then
        return false
    end
    ret, job.month = parse_item(cs[5])
    if not ret then
        return false
    end
    ret, job.weekday = parse_item(cs[6])
    if not ret then
        return false
    end

    return true, job
end

local function calc_time(job, tm)
    local next = 9999999
    if job.weekday.every then
        
    end
    local year = tm.year
    local month
    if job.month.every then
        month = tm.month
    else
        
    end 

end

local function update()
    -- 找到下一个执行时间点，但后
    local tm = os.date("*t")






end

function cron.init()

end

function cron.schedule(crontab, callback)
    local ret, job = parse(crontab)
    if not ret then
        log.info(tag, "parse failed", crontab)
        return false
    end

    job.callback = callback
    job.id = increment
    increment = increment + 1

    -- 缓存
    jobs[job.id] = job
    return true, job.id
end

function cron.delete(id)
    table.remove(jobs, id)
end

return cron
