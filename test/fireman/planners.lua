local planner = require("planner")
local log = iot.logger("planner")

local planners = {}

-- 灭火计划
function planners.extinguish(data)
    return true, {{
        type = "turn_left",
        rounds = 10,
        wait_timeout = 1000
    }, {
        type = "brake"
    }}
end

-- 巡逻任务
function planners.patrol()
    return true, {{
        type = "move",
        speed = 5
    }, {
        type = "cam_left",
        rpm = 5,
        wait = true
    }, {
        type = "wait",
        timeout = 100
    }, {
        type = "cam_right",
        rpm = 5,
        wait = true
    }, {
        type = "wait",
        timeout = 100
    }, {
        type = "repeat", -- 重复执行旋转
        count = 4
    }}
end

-- 注册
planner.register(planners)
