--- 机器人
-- @module robot
local robot = {}
_G.robot = robot -- 注册到全局

local log = iot.logger("robot")

local configs = require("configs")

local Executor = require("executor")
local fsm = require("fsm")
local cron = require("cron")
local planner = require("planner")

local boot = require("boot")

-- 状态机
robot.fsm = fsm:new({
    name = "robot"
})

-- 空状态，避免无法启动，实际项目需要覆盖
robot.fsm:register("idle", {
    name = "空闲",
    tick = function()
        log.info("robot state idle", os.date("%Y-%m-%d %H:%M:%S"))
    end
})

--- 创建计划，并执行
-- @param name string 计划名称
-- @param data any 参数
-- @param branch boolean 支线任务（可选），否则为主线任务
-- @return boolean 成功与否
-- @return string 错误信息 或 结果
function robot.plan(name, data, branch)
    local ret, plan = planner.plan(name, data)
    if not ret then
        return ret, plan
    end

    -- 创建一个虚拟机并执行
    local executor = Executor:new(plan)
    if not branch then
        -- 停止主任务
        if robot.executor then
            robot.executor:stop()
        end
        -- 替换主任务
        robot.executor = executor
    end

    -- 开始执行
    return executor:start()
end

function robot.state(name)
    robot.fsm:switch(name)
end

--- 打开
function robot.open()
    log.info("open")

    -- 加载自定义编程？

    -- 启动计划任务

    -- 启动状态机
    local ret, info = robot.fsm:start("idle")
    if not ret then
        log.error("状态机启动失败", info)
    end

    return true
end

--- 关闭
function robot.close()

    robot.fsm:stop()

    return true
end

robot.deps = {"components", "settings"}

-- 注册
boot.register("robot", robot)

return robot
