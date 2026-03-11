local robot = require("robot")
local components = require("components")

local states = {}

-- 待机状态
states.standby = {
    enter = function()
    end,
    leave = function()
    end,
    tick = function()
    end
}

-- 充电状态
states.charge = {
    enter = function()
        -- 打开充电继电器
    end,
    leave = function()
        -- 关闭充电继电器
    end,
    tick = function()
        -- 检查充电电流
    end
}

-- 巡逻状态
states.patrol = {
    enter = function()
        -- 启动行走电机
    end,
    leave = function()
        -- 停止行走电机
    end,
    tick = function()
        -- 维持速度，自动恢复
    end
}

-- 灭火状态
states.extinguish = {
    enter = function()
        -- 停止行走电机

        -- 创建任务，启动机械臂，方向，接水
    end,
    leave = function()
        -- 创建任务，停水，收回机械臂，方向回正
    end,
    tick = function()
        -- 自动纠正方向，瞄准火源
    end
}

-- 注册状态
robot.fsm:register(states)
