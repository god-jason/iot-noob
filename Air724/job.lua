--- 模块功能：定时器
-- @module job
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30
module(..., package.seeall)

local MOD = "JOB"

local timers = {}

-- 创建一个任务
function start(interval, callback)
    if not timers[interval] then
        timers[interval] = {[callback] = true}
        sys.timerLoopStart(function()
            for i, v in ipairs(timers[interval]) do
                if type(v) == "function" then v() end
            end
            -- sys.timerStop(id)
        end, interval)
    elseif not timers[interval][callback] then
        timers[interval][callback] = true
    end
end

-- 删除一个任务
function stop(interval, callback)
    if timers[interval] then
        if not callback then
            timers[interval] = {}
        elseif timers[interval][callback] then
            timers[interval][callback] = false
        end
    end
end


