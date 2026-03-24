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

robot.executor = Executor:new({})

-- 分支执行器
robot.executors = {}

-- 空状态，避免无法启动，实际项目需要覆盖
robot.fsm:register("init", {
    name = "初始化",
    tick = function()
        log.info("robot tick", os.date("%Y-%m-%d %H:%M:%S"))
    end
})

--- 创建计划，并执行
-- @param name string 计划名称
-- @param data any 参数
-- @param opts table 参数， branch boolean 支线任务（可选），否则为主线任务
-- @return boolean 成功与否
-- @return string 错误信息 或 结果
function robot.plan(name, data, opts)
    opts = opts or {}
    data = data or {}
    local ret, plan = planner.plan(name, data)
    if not ret then
        return ret, plan
    end

    -- 补全参数
    plan.job = opts.job or plan.job or name
    plan.on_finish = opts.on_finish or plan.on_finish
    plan.on_error = opts.on_error or plan.on_error

    -- 创建一个虚拟机并执行
    local executor = Executor:new(plan)

    if opts.branch then
        -- 停止支线任务
        if robot.executors[plan.job] then
            robot.executors[plan.job]:stop()
        end
        -- 替换支线任务
        robot.executors[plan.job] = executor
    else
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

--- 杀死计划
-- @param name string 计划名称
function robot.kill(name)
    if robot.executor and robot.executor.job == name then
        robot.executor:stop()
    end
    -- 找到分支任务
    for k, v in pairs(robot.executors) do
        if k == name then
            v:stop()
            return true
        end
    end
    return false
end

--- 停机
function robot.stop()
    if robot.executor then
        robot.executor:stop()
    end
    for k, v in pairs(robot.executors) do
        v:stop()
    end
    robot.executors = {}
end

function robot.state(name, ...)
    log.info("切换状态", name, ...)
    -- log.info(self.name, "enter", self.next_state)
    return robot.fsm:switch(name, ...)
end

function robot.state_name()
    return robot.fsm.state_name
end

--- 打开
function robot.open()
    log.info("open")

    -- 加载自定义编程？

    -- 启动计划任务

    -- 启动状态机
    local ret, info = robot.fsm:start("init")
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


-- 注册
boot.register("robot", robot, "components", "settings")

return robot
