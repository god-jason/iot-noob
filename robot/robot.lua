local robot = {}
_G.robot = robot --注册到全局

local log = iot.logger("robot")

local configs = require("configs")

local Executor = require("executor")
local fsm = require("fsm")
local cron = require("cron")
local planner = require("planner")

local components = require("components")
local program = require("program")
local boot = require("boot")


robot.fsm = fsm:new()

function robot.plan(name, data)
    local ret, plan = planner.plan(name, data)
    if not ret then
        return ret, plan
    end

    -- 创建一个虚拟机并执行
    robot.executor = Executor:new(plan)
    return robot.executor:start()
end

function robot.open()
    log.info("open")

    -- 加载自定义编程
    local ret, info = program.load()
    if not ret then
        log.error(info)
    end

    -- 启动计划任务

    -- 连接服务器

    -- 启动状态机
    robot.fsm:start()

    return true
end

function robot.close()
    return true
end

robot.deps = {"components", "settings"}

-- 注册
boot.register("robot", robot)

return robot
