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
    local tasks = {}

    -- 判断磁感应
    if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
        sensor.set_position(0)
        --return false, "已经在起点(磁感应)"
        return true, tasks
    end

    -- 判断后接近
    if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
        if sensor.position() < (settings.correct.backward_detect or 50) then
            sensor.set_position(0)
            -- return false, "已经在起点(后接近)"
            return true, tasks
        end
    end

    -- 创建任务
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
                type = "move_end"
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
    table.insert(tasks, {
        name = "清零", -- 清零
        type = "zero",
        speed = 2, -- 2档回到起点
        distance = settings.correct.backward_detect or 100
    })

    -- 起点锁机
    if settings.device.start_lock then
        table.insert(tasks, {
            name = "锁机",
            type = "move_lock"
        })
    end

    -- 先等待2s，避免归零，立马去充电 或 喂料
    table.insert(tasks, {
        type = "wait",
        time = 2000
    })

    return true, tasks
end

-- 归位任务
planner.register("home", function(data)
    local ret, tasks = home_tasks(data)
    if not ret then
        return false, tasks
    end

    -- 已经在起点
    if #tasks == 0 then
        robot.state("idle")
        return false, "已经在起点"
    end

    return true, {
        tasks = tasks,
        on_finish = function()
            robot.state("idle")
        end
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
    if #tasks == 0 then
        robot.state("idle")
        return false, "已经在起点"
    end

    -- 先进入维护模式
    robot.state("standby")

    return true, {
        tasks = tasks,
        on_finish = function()
            -- 移动完成，返回待机状态
            robot.state("idle")
        end
    }
end)

local function open_charge()
    -- 延迟5秒充电
    iot.setTimeout(function()
        battery.charge(true)

        -- 延迟5s开始风干
        iot.setTimeout(function()
            robot.plan("dry")
            -- robot.plan("dry", {}, {
            --     branch = true -- 子进程
            -- })
        end, 5000)
    end, (settings.device.charge_timeout or 5) * 1000)
end

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
        if #tasks > 0 then
            -- 先等待2s，避免归零，立马去充电
            table.insert(tasks, {
                type = "wait",
                time = 2000
            })
        end

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
        table.insert(tasks, {
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

    -- 设备就在原点，
    if #tasks == 0 then
        open_charge()
        return false, "无需行走"
    end

    return true, {
        tasks = tasks,
        on_finish = function()
            open_charge()
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
    local brake = feeder.calc_brake_distance(rpm)

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

    local wait = data.wait or (settings.feed.move_timeout or 10) * 60 -- 平移等待时间 默认等10分钟，之后返回充电
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

    -- 清零
    table.insert(tasks, {
        name = "清零", -- 清零
        type = "zero",
        speed = 2, -- 2档回到起点
        distance = settings.correct.backward_detect or 100
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
    local brake = feeder.calc_brake_distance(rpm)
    local rounds = feeder.calc_move_rounds(data.distance)

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
            time = (data.timeout or 60) * 1000
        }, {
            type = "vibrator_stop"
        }}
    }
end)

-- 风干
planner.register("dry", function(data)
    local tasks = {}

    -- 启动风机
    table.insert(tasks, {
        type = "fan",
        level = settings.dry.fan_level or 3,
        name = "begin"
    })

    -- 震动
    if settings.functions.vibrator and settings.dry.vibrator_time and settings.dry.vibrator_time > 0 then
        table.insert(tasks, {
            type = "vibrator"
        })
        table.insert(tasks, {
            type = "wait",
            time = (settings.dry.vibrator_time or 10) * 1000
        })
        table.insert(tasks, {
            type = "vibrator_stop"
        })
    end

    -- 等待风机结束
    table.insert(tasks, {
        type = "wait",
        time = (settings.dry.dry_time or 120) * 1000
    })
    table.insert(tasks, {
        type = "fan_stop"
    })

    -- 休息
    table.insert(tasks, {
        type = "wait",
        time = (settings.dry.idle_time or 600) * 1000
    })

    -- 继续执行
    table.insert(tasks, {
        type = "jump",
        label = "begin"
    })

    return true, {
        tasks = tasks
    }
end)

planner.register("feed", function(data)
    -- 切换到投喂状态
    robot.state("feed")

    -- 回归任务
    local ret, tasks = home_tasks(data)
    if not ret then
        return false, tasks
    end

    -- 投喂任务
    local ret, plan = feeder.feed(data)
    if not ret then
        return false, plan
    end

    -- 任务拼接
    if #tasks > 0 then
        for i, task in ipairs(plan.tasks) do
            table.insert(tasks, task)
        end
        plan.tasks = tasks
    end

    return true, plan
end)

planner.register("feed_rank", function(data)

    -- 回归任务
    local ret, tasks = home_tasks(data)
    if not ret then
        return false, tasks
    end

    -- 投喂任务
    local ret, plan = feeder.feed_rank(data)
    if not ret then
        return false, plan
    end

    -- 任务拼接
    if #tasks > 0 then
        for i, task in ipairs(plan.tasks) do
            table.insert(tasks, task)
        end
        plan.tasks = tasks
    end

    return true, plan
end)

