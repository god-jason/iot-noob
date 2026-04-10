local robot = require("robot")
local log = iot.logger("states")

local sensor = require("sensor")
local master = require("master")
local vm = require("vm")

local states = {}

states.standby = {
    name = "维护"
}

states.error = {
    name = "错误",
    enter = function(ctx, err)
        master.device:put_values({
            error = true,
            error_string = err or "未知错误"
        })

        -- 关闭所有任务
        robot.stop()
        -- 上报平台
        iot.emit("report")
        -- cloud.report_error(err)
        iot.emit("report_error", err)
    end,
    leave = function()
        master.device:put_values({
            error = false,
            error_string = ""
        })
        -- 启动任务
        robot.state("patrol")

        -- 上报平台
        iot.emit("report")
        -- cloud.clear_error()
        iot.emit("clear_error")
    end
}

states.init = {
    name = "初始化",
    enter = function()
        robot.plan("stop")

        -- 5秒后进入巡逻状态
        iot.setTimeout(function()
            robot.state("patrol")
        end, 5000)
    end
}

-- 巡逻状态
states.patrol = {
    name = "巡逻",
    enter = function()
        -- 启动行走电机，摄像头
        local ret, info = robot.plan("patrol")
        if not ret then
            log.error("启动巡逻计划失败", info)
            return
        end

        ret, info = robot.plan("move", {}, {
            branch = true
        })
        if not ret then
            log.error("启动巡逻行走失败", info)
        end

    end,
    leave = function()
        -- 停止行走电机和摄像头
        robot.stop()
    end,
    tick = function()
        -- 维持速度，自动恢复
        if robot.executors.move then
            -- 如果距离小于100cm，停止行走电机
            if sensor.distance < 100 and components.move_stepper.running then
                components.move_stepper:stop()
                robot.executors.move:pause()
            end
            -- 如果距离大于200cm，恢复行走电机
            if sensor.distance > 200 and not components.move_stepper.running then
                robot.executors.move:resume()
            end
        end
    end
}

-- 灭火状态
states.extinguish = {
    name = "灭火",
    enter = function()
        -- 停止行走电机

        -- 创建任务，启动机械臂，方向，接水
        local ret, info = robot.plan("extinguish", {})
        if not ret then
            log.error("启动灭火计划失败", info)
            return
        end

    end,
    leave = function()
        -- 创建任务，停水，收回机械臂，方向回正
        local ret, info = robot.plan("extinguish_stop", {}, {
            -- 完成之后，恢复巡逻状态
            on_finish = function()
                robot.state("patrol")
            end
        })
        if not ret then
            log.error("启动灭火结束计划失败", info)
            return
        end

        -- 10秒后进入巡逻状态
        iot.setTimeout(function()
            robot.state("patrol")
        end, 30000)
    end,
    tick = function()
        -- 自动纠正方向，瞄准火源
    end
}

-- 注册状态
robot.fsm:register(states)
