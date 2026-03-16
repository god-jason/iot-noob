local robot = require("robot")
local log = iot.logger("states")

local battery = require("battery")
local settings = require("settings")
local feeder = require("feeder")
local sensor = require("sensor")

local states = {}

local function check_limits()
    if components.move_servo.running then
        if components.move_servo.rounds > 0 then
            if settings.device.forward_limit_enable and components.forward_limit.gpio:get() == 0 then
                components.move_servo:stop()
                if sensor.position() > settings.total_length - (settings.correct.forward_detect or 50) then
                    sensor.set_position(settings.total_length)
                end
            end
        else
            if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
                components.move_servo:stop()
                if sensor.position() < (settings.correct.backward_detect or 50) then
                    sensor.set_position(0)
                end
            end
            if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
                components.move_servo:stop()
                if sensor.position() < (settings.correct.backward_detect or 50) then
                    sensor.set_position(0)
                end
            end
        end
    end
end

states.standby = {
    name = "维护"
}

states.init = {
    name = "初始化",
    enter = function()
        battery.charge(false)
        components.led_power:on()
        components.led_feed:on()
        components.led_move:on()
        components.move_servo:unlock()
        components.feed_servo:unlock()
        -- components.fan:close()
    end
}

local idle_ticks = 0

-- 待机状态
states.idle = {
    name = "待机",
    enter = function()
        idle_ticks = 0
    end,
    leave = function()
        idle_ticks = 0
    end,
    tick = function()
        -- 超时自动充电

        -- 空闲模式, 1分钟进入充电
        idle_ticks = idle_ticks + 1

        if idle_ticks > (settings.device.charge_wait or 60) then
            idle_ticks = 0
            robot.plan("charge", {})
        end
    end
}

-- 平移状态
states.move = {
    name = "平移",
    enter = function()
        components.led_move:blink()
    end,
    leave = function()
        components.led_move:on()
    end,
    tick = function()
        -- 检查限位开关
        check_limits()
    end
}

-- 充电状态
states.charge = {
    name = "充电",
    enter = function()
        -- 打开风干任务
    end,
    leave = function()
        -- 关闭充电继电器
        battery.charge(false)

        -- 退出风干任务
        if robot.executors.dry then
            robot.executors.dry:stop()
            robot.executors.dry = nil
        end
    end,
    tick = function()
        -- TODO 检查充电电流

    end
}

-- 投喂状态
states.feed = {
    name = "投喂",
    enter = function()
        -- 归位
        -- 开始闪烁
        components.led_feed:blink()
    end,
    leave = function()
        -- 投喂统计
        -- 关闭闪烁
        if feeder.error then
            components.led_feed:off()
        else
            components.led_feed:on()
        end
    end,
    tick = function()
        -- 检查下一轮任务
        if os.time() > feeder.next() then
            log.info("投喂间隔到，准备下一轮投喂")

            if robot.executor.job == "feed" or robot.executor.job == "feed_rank" then
                log.error("上一轮投喂还没结束")
                feeder.next(os.time() + 1 * 60 * 1000) -- 顺延1分钟
            else
                local ret, info = robot.plan("feed_rank")
                -- local ret, info = feeder.feed_rank()
                if not ret then
                    log.info("投喂失败", info)
                    iot.emit("log", "投喂启动失败：" .. info)
                end
            end
        end

        -- 检查限位开关
        check_limits()
    end
}

-- 注册状态
robot.fsm:register(states)
