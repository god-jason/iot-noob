local planner = require("planner")
local log = iot.logger("planner")

local agent = require("agent")
local robot = require("robot")
local settings = require("settings")
local sensor = require("sensor")
local feeder = require("feeder")
local battery = require("battery")

local planners = {}

local function home_tasks(data)
    -- 判断磁感应
    if settings.device.meg_sensor_enable and components.meg_sensor:get() == 0 then
        sensor.set_position(0)

        if cb ~= nil then
            cb()
        end
        return false, "已经在起点(磁感应)"
    end

    -- 判断后接近
    if settings.device.backward_limit_enable and components.backward_limit:get() == 0 then
        if sensor.position() < (settings.correct.backward_detect or 50) then
            sensor.set_position(0)

            if cb ~= nil then
                cb()
            end
            return false, "已经在起点(后接近)"
        end
    end

    -- 创建任务
    local tasks = {}
    local distance, rounds

    local position = sensor.position()
    if position < 10 then
        return true, tasks
    end

    -- 要走出充电位
    if position > 50 then
        -- TODO 应该根据位置判断
        if battery.charging then
            battery.charge(false)

            local charge_distance = 30

            table.insert(tasks, {
                name = "走出充电位",
                type = "move",
                speed = 2, -- 2档走出
                distance = charge_distance,
                rounds = feeder.calc_move_rounds(charge_distance),
                wait = true
            })

            table.insert(tasks, {
                type = "brake"
            })

            table.insert(tasks, {
                name = "等待停止",
                type = "wait",
                time = 2000
            })

            -- 走出充电位
            position = position + charge_distance
        end
    end

    -- 如果距离远，需要先快速跑回去
    if position > 50 then
        distance = -position + 50
        rounds = feeder.calc_move_rounds(distance)

        table.insert(tasks, {
            name = "返回起点",
            type = "move",
            speed = settings.feed.move_speed,
            rounds = rounds,
            distance = distance,
            wait = true
        })
        table.insert(tasks, {
            type = "move_end"
        })

        position = position + distance
    end

    -- 再减速逼近起点，直到-100cm，实现归零
    distance = -(settings.correct.backward_detect or 100) - position
    rounds = control.calc_move_rounds(distance)

    table.insert(tasks, {
        name = "清零", -- 清零
        type = "move",
        speed = 2, -- 2档回到起点
        rounds = rounds,
        distance = distance,
        wait = true
    })
    table.insert(tasks, {
        type = "move_end"
    })

    -- 起点锁机
    if settings.device.start_lock then
        table.insert(tasks, {
            name = "锁机",
            type = "move_lock"
        })
    end

    return true, tasks
end

-- 归位任务
planner.register("home", function(data)
    local ret, tasks = home_tasks(data)
    if not ret then
        return ret, tasks
    end
    return true, {
        tasks = tasks
        -- on_finish = data.on_finish
    }
end)

-- 距离前进
planner.register("move_forward", function(data)
    -- robot.mode = "standby"
    robot.state("standby")

    local position = sensor.position()
    if position > settings.total_length - 10 then
        return false, "已经到终点"
    end

    local rpm = feeder.calc_move_rpm(settings.feed.move_speed)
    local brake = feeder.calc_brake_distance(rpm)

    local distance = settings.total_length - position - brake
    local rounds = feeder.calc_move_rounds(distance)

    local tasks = {}

    table.insert(tasks, {
        type = "move", -- 前进到终点
        speed = settings.feed.move_speed,
        distance = distance,
        rounds = rounds,
        wait = true
    })

    table.insert(tasks, {
        name = "刹车",
        type = "brake"
    })

    -- 终点锁机
    if settings.device.finish_lock then
        table.insert(tasks, {
            name = "锁机",
            type = "move_lock"
        })
    end

    return true, {
        tasks = tasks
        -- on_finish = data.on_finish
    }
end)

-- 距离后退
planner.register("move_backward", function(data)
    local ret, tasks = home_tasks(data)
    if not ret then
        return false, tasks
    end
    return true, {
        tasks = tasks,
        on_finish = function()
            -- 移动完成，返回待机状态
            robot.state("idle")
        end
    }
end)

-- 充电
planner.register("charge", function(data)

    -- 切换到充电状态
    robot.state("charge")

    -- 先回来原点
    local ret, tasks = home_tasks(data)
    if not ret then
        return false, tasks
    end

    -- 充电位不在原点，前进到充电位
    if settings.charge_position > 10 then
        local rpm = feeder.calc_move_rpm(settings.feed.move_speed)
        local brake = feeder.calc_brake_distance(rpm)
        local distance = settings.charge_position - brake
        local rounds = feeder.calc_move_rounds(distance)

        -- 前进到充电位
        table.insert(tasks, {
            type = "move",
            speed = settings.feed.move_speed,
            distance = distance,
            rounds = rounds,
            position = settings.charge_position - brake, -- 目标位置
            wait = true
        })
        table.insert({
            type = "move_end"
        })

        -- 刹车
        table.insert(tasks, {
            name = "刹车",
            type = "brake"
        })

        -- 充电锁机
        if settings.device.charge_lock then
            table.insert(tasks, {
                name = "锁机",
                type = "move_lock"
            })
        end
    end

    return true, {
        tasks = tasks,
        on_finish = function()
            -- 延迟5秒充电
            iot.setTimeout(function()
                battery.charge(true)
            end, (settings.device.charge_timeout or 5) * 1000)
        end
    }
end)

-- 平移
planner.register("move", function(data)
    robot.state("move")

    -- battery.charge(1)
    local position = sensor.position()
    if position > settings.total_length - 10 then
        -- log.info("已在终点位置")
        return false, "已在终点位置"
    end

    local tasks = {}

    local rpm = feeder.calc_move_rpm(settings.feed.move_speed)
    local brake = feeder.calc_brake_distance(settings.feed.move_speed)

    local distance = settings.total_length - position - brake
    local rounds = feeder.calc_move_rounds(distance)

    -- 创建一个平移任务
    table.insert(tasks, {
        type = "move", -- 前进到终点
        speed = settings.feed.move_speed,
        distance = distance,
        rounds = rounds,
        wait = true
    })
    table.insert(tasks, {
        type = "move_end"
    })

    table.insert(tasks, {
        name = "刹车",
        type = "brake"
    })

    -- 终点锁机
    if settings.device.finish_lock then
        table.insert(tasks, {
            name = "锁机",
            type = "move_lock"
        })
    end

    local wait = data.wait or settings.feed.move_timeout or 600 -- 平移等待时间 默认等10分钟，之后返回充电
    -- 等待
    table.insert(tasks, {
        type = "wait",
        time = wait * 1000
    })

    -- 回到起点
    distance = -settings.total_length + (settings.correct.backward_detect or 50)
    rounds = feeder.calc_move_rounds(distance)

    table.insert(tasks, {
        name = "返回起点",
        type = "move",
        speed = settings.feed.move_speed,
        rounds = rounds,
        distance = distance,
        wait = true
    })
    table.insert(tasks, {
        type = "move_end"
    })

    -- 减速逼近起点
    distance = -100 - (settings.correct.backward_detect or 50) -- 要运行到起点之前50cm，实现位置清零
    rounds = feeder.calc_move_rounds(distance)

    table.insert(tasks, {
        name = "zero", -- 清零
        type = "move",
        speed = 2, -- 2档回到起点
        rounds = rounds,
        distance = distance,
        wait = true
    })
    table.insert(tasks, {
        type = "move_end"
    })

    -- 起点锁机
    if settings.device.start_lock then
        table.insert(tasks, {
            name = "锁机",
            type = "move_lock"
        })
    end

    return true, {
        tasks = tasks,
        on_finish = function()
            -- 平移结束，进入待机状态，然后进入充电状态
            robot.state("idle")
        end
    }
end)

-- 强制前进&后退
planner.register("force_move", function(data)
    robot.state("standby")

    local tasks = {}

    local rpm = feeder.calc_move_rpm(data.speed or 5)
    local brake = robot.calc_brake_distance(rpm)
    local rounds = robot.calc_move_rounds(data.distance)

    -- 创建一个平移任务
    table.insert(tasks, {
        type = "move", -- 前进到终点
        speed = data.speed or 5,
        distance = data.distance,
        rounds = rounds,
        force = true, -- 强制移动
        wait = true
    })
    table.insert(tasks, {
        type = "move_end"
    })

    table.insert(tasks, {
        name = "刹车",
        type = "brake"
    })

    return true, {
        tasks = tasks
    }
end)

-- 震动
planner.register("vibrator", function(data)
    return true, {
        tasks = {{
            type = "vibrator"
        }, {
            type = "wait",
            timeout = (data.timeout or 60) * 1000
        }, {
            type = "vibrator_stop"
        }}
    }
end)

-- 风干
planner.register("dry", function(data)
    local tasks = {}
    table.insert(tasks, {
        type = "fan",
        level = settings.dry.fan_level or 3
    })

    -- 震动
    if settings.functions.vibrator and settings.dry.vibrator_time and settings.dry.vibrator_time > 0 then
        table.insert(tasks, {
            type = "vibrator"
        })
        table.insert(tasks, {
            type = "wait",
            timeout = (settings.dry.vibrator_time or 10) * 1000
        })
        table.insert(tasks, {
            type = "vibrator_stop"
        })
    end

    -- 等待风机结束
    table.insert(tasks, {
        type = "wait",
        timeout = (settings.dry.dry_time or 120) * 1000
    })
    table.insert(tasks, {
        type = "fan_stop"
    })

    -- 休息
    table.insert(tasks, {
        type = "wait",
        timeout = (settings.dry.idle_time or 600) * 1000
    })

    return true, tasks
end)

planner.register("feed", function(data)
    -- 切换到投喂状态
    robot.state("feed")
    return feeder.feed()
end)

planner.register("feed_rank", function(data)
    return feeder.feed_rank()
end)

