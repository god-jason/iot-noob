--- CPU统计
-- @module cpu
local cpu = {}

local start = os.clock()
local interval = 10

cpu.usage = 0

local function tick()
    local finish = os.clock()
    log.info("cpu usage", start, finish)
    cpu.usage = (finish - start) * 100 / interval
    start = finish
end


sys.timerLoopStart(tick, interval * 1000)

return cpu
