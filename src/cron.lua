--- 定时任务相关(目前还不支持星期)
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
    for i, s in ipairs(is) do
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

    local ret = false

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

local function calc_next(job, now)
    -- log.info(tag, "calc_next()", job.crontab)

    -- 复制当前时间，并延后1秒再执行
    local next = now + 1

    local items = {"year", "month", "day", "hour", "min", "sec"}

    local added = true

    -- 迭代计算下一个时间
    while added do
        added = false

        local tm = os.date("!*t", next)
        -- log.info(tag, "next begin", json.encode(tm))

        for i, f in ipairs(items) do
            -- log.info(tag, "calc_next", f)
            if i > 1 then -- 跳过年
                local field = job[f]
                if field.every then
                    -- log.info(tag, "calc_next every", f)
                    -- 所有，不用计算了
                elseif field.mod then
                    -- 计算模
                    -- log.info(tag, "calc_next mod", f)
                    while tm[f] % field.mod ~= 0 do
                        -- log.info(tag, "calc_next mod", f, tm[f])
                        tm[f] = tm[f] + 1
                        added = true
                    end
                else
                    -- 计算散列
                    -- log.info(tag, "calc_next dot", f)
                    while not field[tostring(tm[f])] do
                        -- log.info(tag, "calc_next dot", f, tm[f])
                        tm[f] = tm[f] + 1

                        -- 统一处理
                        if tm[f] > 100 then
                            local ff = items[i - 1]
                            tm[ff] = tm[ff] + 1
                            tm[f] = 0
                        end
                        added = true
                    end
                end
            end
        end

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
    for c, job in pairs(jobs) do
        if not job.next then
            calc_next(job, now)
        elseif job.next <= now then
            for id, cb in pairs(job.callbacks) do
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
    local ret, job = parse(crontab)
    if not ret then
        log.info(tag, "parse failed", crontab)
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
