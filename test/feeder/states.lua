local robot = require("robot")
local log = iot.logger("states")

local battery = require("battery")
local settings = require("settings")
local feeder = require("feeder")

local states = {}

states.standby = {
    name = "维护"
}

-- 待机状态
states.idle = {
    name = "待机",
    enter = function()
        -- 打开风干任务
        robot.plan("dry", {}, {
            branch = true -- 子进程
        })
    end,
    leave = function()
        -- 退出风干任务
        if robot.executors.dry then
            robot.executors.dry:stop()
            robot.executors.dry = nil
        end
    end,
    tick = function()
        -- 超时自动充电
    end
}

-- 充电状态
states.charge = {
    name = "充电",
    enter = function()
        -- 走到充电位，打开充电继电器
        -- 开始闪烁
        components.led_power:blink()
    end,
    leave = function()
        -- 关闭充电继电器
        battery.charge(false)
        -- 关闭LED闪烁
        components.led_power:on()
    end,
    tick = function()
        -- 检查充电电流

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

        -- 开始闪烁
        components.led_feed:on()
    end,
    tick = function()

        -- 检查下一轮任务
        if os.time() > next_feed_time then
            log.info("投喂间隔到，准备下一轮投喂")
            local ret, info = robot.plan("feed_rank")
            -- local ret, info = feeder.feed_rank()
            if not ret then
                log.info("投喂失败", info)
                iot.emit("device_log", "投喂启动失败：" .. info)
            end
        end

        -- 投喂模式

    end
}

-- 注册状态
robot.fsm:register(states)
