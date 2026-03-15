local planner = require("planner")
local log = iot.logger("planner")

local agent = require("agent")
local robot = require("robot")

local planners = {}

-- 全部停止
function planners.stop(data)
    return true, {{
        type = "move_stop"
    }, {
        type = "water_stop"
    }, {
        type = "turn_stop"
    }, {
        type = "arm_stop"
    }}
end

-- 巡逻任务
function planners.patrol(data)
    return true, {{
        type = "move",
        speed = data.speed or 5
    }, {
        name = "cam",
        type = "cam_right",
        rpm = data.rpm or 5,
        wait = true
    }, {
        type = "wait",
        timeout = 100
    }, {
        type = "cam_left",
        rpm = data.rpm or 5,
        wait = true
    }, {
        type = "wait",
        timeout = 100
    }, {
        type = "goto", -- 重复执行旋转
        label = "cam"
    }}
end

-- 摄像头到指令角度
function planners.cam_angle(data)
    return true, {{
        type = "cam_left",
        rpm = data.rpm or 5,
        wait = true
    }, {
        type = "wait",
        timeout = 100
    }, {
        type = "cam_angle",
        rpm = 5,
        angle = data.angle,
        wait = true
    }}
end

-- 灭火任务
function planners.extinguish(data)
    return true, {{ -- 摄像头水位
        type = "cam_left",
        rpm = data.cam_rpm or 5,
        wait = true
    }, {
        type = "wait",
        timeout = 100
    }, {
        type = "cam_angle",
        rpm = data.cam_rpm or 5,
        angle = 0, -- 摄像头 转到0度
        wait = true
    }, {
        type = "turn_angle", -- 机身旋转
        rpm = data.turn_rpm or 60,
        angle = data.turn_angle or 30,
        wait = true
    }, {
        type = "arm_angle", -- 机械臂旋转
        rpm = data.arm_rpm or 60,
        angle = data.arm_angle or 30,
        wait = true
    }, {
        type = "water_up", -- 接水
        wait = true
    }}
end

-- 灭火任务结束
function planners.extinguish_stop(data)
    return true, {{
        type = "water_down",
        wait = true
    }, {
        type = "water_stop",
        wait = true
    }, {
        type = "arm_back",
        wait = true
    }, {
        type = "arm_stop",
        wait = true
    }, {
        type = "turn_back",
        wait = true
    }, {
        type = "turn_stop",
        wait = true
    }}
end

-- 注册
for k, v in pairs(planners) do

    -- 注册到计划
    planner.register(k, v)

    -- 注册命令，远程调用
    agent.register(k, function(data)
        log.info("plan", k, iot.json_encode(data))
        return robot.plan(k, data)
    end)
end

