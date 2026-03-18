local feeder = {}

local log = iot.logger("controls")

local boot = require("boot")
local settings = require("settings")
local configs = require("configs")
local sensor = require("sensor")
local robot = require("robot")
local battery = require("battery")
local schedule = require("schedule")
local master = require("master")

-- 每圈的距离，齿比20:70，直径8cm
feeder.distance_per_round = 20 / 70 * math.pi * 8

-- 投喂电机
feeder.weight_per_round = 10 -- 每圈的重量 g/records 会根据料不同 产生变化

local options = configs.load_default("robot", {
    auto = true, -- 自动模式
    smart = true -- 智能模式
})

-- 计算距离
function feeder.calc_move_distance(rounds)
    return rounds * feeder.distance_per_round
end

-- 计算行走圈数
function feeder.calc_move_rounds(distance)
    return distance / feeder.distance_per_round
end

-- 计算移动转速
function feeder.calc_move_rpm(speed)
    return components.move_speeder:calc(speed)
end

-- 计算行走用时 ms
function feeder.calc_move_time(rpm, distance)
    local rounds = distance / feeder.distance_per_round
    local time = rounds / rpm * 60 * 1000 -- ms
    return math.abs(math.floor(time))
end

-- 计算刹车距离
function feeder.calc_brake_distance(rpm)
    local tm, rounds = components.move_servo:calc_accelerate(rpm, 0)
    return rounds * feeder.distance_per_round
end

-- 计算投喂时间 ms
function feeder.calc_feed_time(rpm, weight)
    local time = weight / feeder.weight_per_round / rpm * 1000 * 60
    return math.abs(math.floor(time))
end

-- 计算投喂圈数
function feeder.calc_feed_rounds(weight)
    return weight / feeder.weight_per_round
end

-- 计算投喂转速 g ms
function feeder.calc_feed_speed(weight, tm)
    return weight / feeder.weight_per_round / tm * 1000 * 60
end

-- 当前分钟数， 找最近的一餐
function feeder.find_nearest_food()
    local now = os.date("*t")
    local now_minute = now.hour * 60 + now.min

    local diff_minute = 24 * 60
    local nearest_food = nil

    for i = 1, 8, 1 do
        local food = settings["food" .. i]
        if food ~= nil and food.enable and food.start ~= nil then
            local h, m = food.start:match("(%d+):(%d+)")
            if h ~= nil and m ~= nil then
                local minute = tonumber(h) * 60 + tonumber(m)
                local diff = math.abs(now_minute - minute)
                if diff < diff_minute then
                    diff_minute = diff
                    nearest_food = i
                end
            end
        end
    end

    return nearest_food
end

-- 充电位
settings.charge_position = 0

-- 总棚长
settings.total_length = 0

-- 关键节点
local all_points = {} -- 全部节点

-- 每段的长度
local feed_lengths = {}

-- 规整数据，把毛竹插入到正确的位置
function feeder.normalize()

    settings.charge_position = 0
    settings.total_length = 0

    for k, v in pairs(settings.distance) do
        if k:startsWith("length") then
            if v > settings.total_length then
                settings.total_length = v
            end
        elseif k == "charge" then
            -- 数据录入为米，以喷嘴为准电刷，需要加20cm
            if v > 0.1 then
                settings.charge_position = v * 100 + 20 -- 转cm，实时以喷嘴测量，机身上喷嘴离电刷25cm
            else
                settings.charge_position = v * 100
            end
        end
    end
    settings.total_length = settings.total_length * 100 -- 转cm

    log.info("总棚长", settings.total_length, "充电位", settings.charge_position)

    -- 计算点位
    local pool = 1
    all_points = {}

    -- 准备
    table.insert(all_points, {
        name = "起点",
        type = "prepare",
        position = 0,
        pool = 1
    })

    -- 投喂起始
    table.insert(all_points, {
        type = "feed",
        position = 0,
        pool = 1
    })

    -- 距离参数转为数组
    local distances = {}
    for k, v in pairs(settings.distance) do
        -- 只保留正值
        if v > 0.1 then
            table.insert(distances, {
                type = k,
                position = v * 100 -- 转cm
            })
        end
    end

    -- 排序 从近到远
    table.sort(distances, function(a, b)
        return a.position < b.position
    end)

    -- 遍历节点，进行规整，方便后续生成指令
    for k, point in ipairs(distances) do
        if point.type:startsWith("board") then

            -- 料台投喂
            table.insert(all_points, {
                name = "料台",
                type = "board",
                position = point.position,
                pool = pool
            })

            -- 行走投喂
            table.insert(all_points, {
                type = "feed",
                position = point.position,
                pool = pool
            })

        elseif point.type:startsWith("dam") then

            pool = tonumber(point.type:sub(4)) + 1 -- 遇到葛坝，下一个棚开始

            -- 准备
            table.insert(all_points, {
                name = "葛坝",
                type = "prepare",
                position = point.position,
                pool = pool
            })

            -- 行走投喂
            table.insert(all_points, {
                type = "feed",
                position = point.position,
                pool = pool
            })

        elseif point.type:startsWith("length") then

            -- 棚结束
            table.insert(all_points, {
                name = "结束",
                type = "finish",
                position = point.position,
                pool = pool
            })

        elseif point.type:startsWith("bamboo") and settings.functions.bamboo then

            -- 插入一个毛竹开始节点
            table.insert(all_points, {
                name = "毛竹",
                type = "bamboo",
                position = point.position - (settings.device.bamboo_distance or 30), -- 毛竹提前量
                pool = pool
            })

            -- 行走投喂
            table.insert(all_points, {
                type = "feed",
                position = point.position + 5, -- 行走5cm，跳过毛竹
                pool = pool
            })

        elseif point.type:startsWith("charge") and settings.functions.bamboo then

            -- 充电位视作一个毛竹， 插入一个毛竹开始节点
            table.insert(all_points, {
                name = "充电位",
                type = "bamboo",
                position = point.position - (settings.device.bamboo_distance or 30), -- 毛竹提前量
                pool = pool
            })

            -- 行走投喂
            table.insert(all_points, {
                type = "feed",
                position = point.position + 5, -- 行走5cm，跳过毛竹
                pool = pool
            })
        end
    end

    -- TODO 毛竹设置在棚外，需要剔除

    log.info("normalize points", json.encode(all_points))

    feed_lengths = {0, 0, 0, 0}

    -- 计算每段的有效长度
    local len = 0
    local start = 0
    for i, p in ipairs(all_points) do
        if p.type == "feed" and i < #all_points then
            local len = all_points[i + 1].position - p.position
            feed_lengths[p.pool] = feed_lengths[p.pool] + len
        end
    end

    log.info("有效投喂距离", json.encode(feed_lengths))
end

-- 创建单次计划 计划，重量，趟数，料台次数，智能模式，单餐补偿
function feeder.plan(plans, weights, ranks, board_times, single)
    local tasks = {}

    local plan = {} -- 当前记录

    local remain_ranks = ranks - #plans -- 剩余趟数

    local pools = 0

    -- 计算一趟的投喂量
    for i, v in ipairs(weights) do
        -- 只处理 有效重量 和 有效棚长   
        if v > 0 and feed_lengths[i] > 0 then
            -- 当前棚的剩余料
            local weight = v

            if options.smart then
                -- 减去已投喂的量
                for j, p in ipairs(plans) do
                    if p[i] and p[i].final_weight then
                        weight = weight - p[i].final_weight
                        -- log.info("计算剩余重量", i, p[i].final_weight, weight)
                    end
                end

                -- log.info("计算剩余重量", i, v, weight)

                -- 智能模式，平均分配剩余重量
                if remain_ranks > 1 then
                    weight = weight / remain_ranks
                end

                -- 最后一趟，添加补偿
                if remain_ranks <= 1 and single then
                    weight = weight + settings.correct.weight_correct
                end

                -- 避免出现负值
                if weight < 0 then
                    weight = 0
                end
            else
                -- 非智能模式，平均分配
                weight = weight / ranks
            end

            -- 当前棚的量平分
            local obj = {
                weight = weight, -- 目标重量
                board_weight = 0,
                move_speed = settings.feed.feed_move_speed -- 取默认速度
            }

            -- 补偿不喂料台
            -- 料台比例，优先后几次
            if remain_ranks > 0 and remain_ranks <= board_times then
                obj.board_weight = obj.weight * settings.feed.board_percent / 100
                obj.move_weight = obj.weight - obj.board_weight
                obj.board_speed = feeder.calc_feed_speed(obj.board_weight, 10 * 1000) -- 计算料台投喂速度

                -- 避免料台速度过快
                if obj.board_speed > 80 then
                    obj.board_speed = 80
                end
            else
                obj.move_weight = obj.weight -- 行走投喂重量
            end

            if remain_ranks > 0 then
                -- 计算速度
                local rpm = feeder.calc_move_rpm(obj.move_speed)
                local tm = feeder.calc_move_time(rpm, feed_lengths[i]) -- 行走时长
                obj.speed = feeder.calc_feed_speed(obj.move_weight, tm) -- 计算投喂速度

                -- 最小速度
                if obj.speed < settings.device.feed_speed_min then
                    obj.speed = settings.device.feed_speed_min
                end

                -- 如果下料转速过快，则降档 
                while obj.speed > settings.device.feed_speed_max and obj.move_speed > 1 do
                    obj.move_speed = obj.move_speed - 1
                    local rpm = feeder.calc_move_rpm(obj.move_speed)
                    local tm = feeder.calc_move_time(rpm, feed_lengths[i]) -- 行走时长
                    obj.speed = feeder.calc_feed_speed(obj.move_weight, tm) -- 计算投喂速度
                end

                -- 如果降档到1档，仍旧无法满足，按最大速度执行
                if obj.speed > settings.device.feed_speed_max then
                    obj.speed = settings.device.feed_speed_max
                end

            else
                -- 补偿，全速跑，全速喂
                obj.speed = settings.feed.feed_speed
            end

            table.insert(plan, obj)
            pools = pools + 1
        else
            table.insert(plan, {})
        end
    end

    -- TODO 这一段代码无效

    -- 如果只有一个棚，则全程投喂，避免剩料
    if pools == 1 and remain_ranks == 0 then
        for i, plan in ipairs(plans) do
            if plan.weight then
                local rpm = feeder.calc_move_rpm(settings.feed.feed_move_speed)
                local tm = feeder.calc_move_time(rpm, feed_lengths[i]) -- 计算时长
                local weight = feeder.weight_per_round * settings.feed.feed_speed * tm / 60 -- 计算总重量
                plan.weight = weight
            end
        end
    end

    log.info("投喂计划", json.encode(plan))
    table.insert(plans, plan)

    -- 节点过滤
    local points = {}
    for i, p in ipairs(all_points) do
        if weights[p.pool] <= 0 then
            -- 该棚无效，跳过
        elseif plan[p.pool] and plan[p.pool].weight <= 0 then
            -- 已经喂完，直接跳过
        elseif (remain_ranks < 1 or remain_ranks > board_times) and p.type == "board" then
            -- 优先后面的料台投喂
            -- 补偿跳过料台投喂
        else
            table.insert(points, p)
        end
    end

    log.info("plan points", json.encode(points))
    if #points == 0 then
        -- 无有效点
        return tasks
    end

    local distance = 0
    local weight = 0
    local rounds = 0

    -- 起始点，静置称重
    if options.smart then
        table.insert(tasks, {
            pool = 0,
            type = "wait",
            time = 10000
        })
        table.insert(tasks, {
            pool = 0,
            type = "weigh",
            wait = true -- not immediate -- 立即执行时，为了用户体验，不等待
        })
    end

    -- log.info("remain_ranks", remain_ranks)
    -- log.info("settings vibrator", settings.feed.vibrator, settings.functions.vibrator)

    -- 震动器启动
    if settings.functions.vibrator then
        -- 冬日和最后一趟启动震动器
        if settings.feed.vibrator or remain_ranks <= 1 then
            table.insert(tasks, {
                pool = 0,
                type = "vibrator"
            })
        end
    end

    -- 依次处理所有关键点
    for i, point in ipairs(points) do

        local next_point
        if i < #points then
            next_point = points[i + 1]
        end

        if point.type == "prepare" then

            -- 启动风机 1s
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "fan",
                level = settings.feed.feed_fan_level
            })

            table.insert(tasks, {
                pool = point.pool,
                type = "wait",
                time = 1000
            })

        elseif point.type == "board" then

            -- 料台投喂 风机降速
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "fan",
                level = settings.feed.board_fan_level
            })

            -- 计算料台投喂量
            weight = plan[point.pool].board_weight
            rounds = feeder.calc_feed_rounds(weight)

            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "feed",
                speed = plan[point.pool].board_speed,
                weight = weight,
                rounds = rounds,
                wait = true -- 等待投喂结束
            })
            table.insert(tasks, {
                type = "feed_end"
            })

        elseif point.type == "feed" then

            -- 行进投喂
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "fan",
                level = settings.feed.feed_fan_level
            })

            -- 计算投喂量            
            distance = next_point.position - point.position
            -- weight = (plan[point.pool].weight - plan[point.pool].board_weight) * distance / feed_lengths[point.pool]
            -- rounds = control.calc_feed_rounds(weight)
            local rpm = feeder.calc_move_rpm(plan[point.pool].move_speed)
            local tm = feeder.calc_move_time(rpm, distance) -- 计算时长
            rounds = plan[point.pool].speed * tm / 60 / 1000 -- 计算实际圈数
            weight = rounds * feeder.weight_per_round

            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "feed",
                speed = plan[point.pool].speed,
                weight = weight,
                rounds = rounds
            })

            -- 下个任务是料台，需要减速停止
            local stop = false
            if next_point ~= nil then
                if next_point.type == "board" then
                    stop = true
                elseif next_point.type == "finish" then
                    -- 没有下一个棚了，需要减速
                    if i + 2 > #points then
                        -- TODO 这个代码有点丑
                        stop = true
                    end
                end
            end

            local brake = 0
            if stop then
                -- 减去刹车距离
                local rpm = feeder.calc_move_rpm(plan[point.pool].move_speed)
                brake = feeder.calc_brake_distance(rpm)
                distance = distance - brake
            end

            -- 行走投喂
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "move",
                speed = plan[point.pool].move_speed,
                distance = distance,
                rounds = feeder.calc_move_rounds(distance),
                position = next_point.position - brake, -- 目标位置
                stop = stop,
                wait = true -- 等待任务结束
            })
            table.insert(tasks, {
                type = "move_end"
            })

            -- 刹车
            if stop then
                table.insert(tasks, {
                    pool = point.pool,
                    name = "刹车",
                    type = "brake",
                    position = next_point.position
                })
            end

            -- 行走投喂，未等待，需要在行走结束后执行
            table.insert(tasks, {
                type = "feed_end"
            })


        elseif point.type == "bamboo" then
            -- 毛竹避障

            -- 停止投喂
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "feed_stop"
            })
            -- 1s降风机
            -- table.insert(tasks, {
            --     pool = point.pool,
            --     type = "wait",
            --     time = 1000
            -- })
            table.insert(tasks, {
                pool = point.pool,
                type = "fan",
                level = settings.device.bamboo_fan_level or 2
            })

            -- 降速
            distance = next_point.position - point.position
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "move",
                speed = settings.device.bamboo_move_speed or 3,
                distance = distance,
                position = next_point.position,
                rounds = feeder.calc_move_rounds(distance),
                wait = true
            })
            table.insert(tasks, {
                type = "move_end"
            })

        elseif point.type == "finish" then

            -- 棚结束，继续下一个
            table.insert(tasks, {
                pool = point.pool,
                name = point.name,
                type = "feed_stop"
            })
            table.insert(tasks, {
                pool = point.pool,
                type = "wait",
                time = 1000 -- 等待1s，料吹完
            })
            table.insert(tasks, {
                pool = point.pool,
                type = "fan_stop"
            })

            local rpm = feeder.calc_move_rpm(settings.feed.move_speed)
            local brake = feeder.calc_brake_distance(rpm)
            -- local brake = control.calc_brake_distance(plan[point.pool].move_speed)
            log.info("brake", brake)

            -- 如果未结束，则走到下一个葛坝，否则回到起点
            if next_point ~= nil then
                distance = next_point.position - point.position
                table.insert(tasks, {
                    pool = point.pool,
                    name = "去下一个棚",
                    type = "move",
                    speed = settings.feed.move_speed,
                    distance = distance - brake,
                    rounds = feeder.calc_move_rounds(distance - brake),
                    position = next_point.position - brake, -- 目标位置
                    wait = true -- 等待任务结束
                })
                table.insert(tasks, {
                    type = "move_end"
                })

                table.insert(tasks, {
                    pool = point.pool,
                    name = "刹车",
                    type = "brake",
                    position = next_point.position
                })

            else

                -- 停止震动器
                if settings.functions.vibrator then
                    if settings.feed.vibrator or remain_ranks <= 1 then
                        table.insert(tasks, {
                            pool = point.pool,
                            type = "vibrator_stop"
                        })
                    end
                end

                -- 等待停稳，再返程
                table.insert(tasks, {
                    pool = point.pool,
                    type = "wait",
                    time = 5000 -- 等5s再返回，避免抖动
                })

                -- 回到起点
                distance = -settings.total_length + 80
                rounds = feeder.calc_move_rounds(distance)

                table.insert(tasks, {
                    pool = point.pool,
                    name = "返回起点",
                    type = "move",
                    speed = settings.feed.move_speed,
                    rounds = rounds,
                    distance = distance,
                    position = 80,
                    wait = true
                })
                table.insert(tasks, {
                    type = "move_end"
                })

                -- 减速逼近起点
                table.insert(tasks, {
                    name = "清零", -- 清零
                    type = "zero",
                    speed = 2, -- 2档回到起点
                    distance = 80 + (settings.correct.backward_detect or 0)
                })
            end

            -- 静置称重
            if options.smart then
                table.insert(tasks, {
                    pool = 0,
                    type = "wait",
                    time = 10000
                })
                table.insert(tasks, {
                    pool = point.pool,
                    name = "称重",
                    type = "weigh",
                    wait = true
                })
            end
        end
    end

    -- 任务结束
    -- table.insert(tasks, {
    --     name = "停止",
    --     type = "stop"
    -- })

    log.info("plan result", json.encode(tasks))

    return tasks
end

local current_plans = {}
local current_food = {}
local current_weights = {0, 0, 0, 0}
local current_checked = false -- 检查完成
local current_correct = false -- 启用补偿，单餐标识
local next_feed_time = 0
local wait_times = 0

function feeder.next(tm)
    if tm == nil then
        return next_feed_time
    end
    next_feed_time = tm
end

local function formatFloat(val)
    return string.format("%.2f", val or 0)
end

local function planLog()
    local plan = current_plans[#current_plans]
    local msg = "第" .. #current_plans .. "轮：\r\n"
    for i, pool in ipairs(plan) do
        msg = msg .. i .. "\r\n"
        if pool.weight ~= nil then
            msg = msg .. "目标重量" .. formatFloat(pool.weight) .. "\r\n"
        end
        if pool.move_speed ~= nil then
            msg = msg .. "行走速度" .. pool.move_speed .. "\r\n"
        end
        if pool.board_weight ~= nil and pool.board_speed ~= nil then
            msg = msg .. "料台重量" .. formatFloat(pool.board_weight) .. "\r\n"
            msg = msg .. "料台转速" .. formatFloat(pool.board_speed) .. "\r\n"
        end
        if pool.move_weight ~= nil and pool.speed ~= nil then
            msg = msg .. "行走重量" .. formatFloat(pool.move_weight) .. "\r\n"
            msg = msg .. "投喂转速" .. formatFloat(pool.speed) .. "\r\n"
        end
        if pool.final_weight ~= nil then
            msg = msg .. "实际重量" .. formatFloat(pool.final_weight) .. "\r\n"
        end
    end
    return msg
end

local vm_names = {
    move = "行走",
    move_stop = "停止行走",
    move_lock = "锁机",
    feed = "投喂",
    feed_stop = "停止投喂",
    wait = "等待",
    weigh = "称重",
    fan = "风机启动",
    fan_stop = "风机停止",
    brake = "刹车",
    stop = "停止",
    vibrator = "震动器启动",
    vibrator_stop = "震动器停止"
}

local function feedLog()
    local msg = "第" .. #current_plans .. "轮：\r\n"
    for i, task in ipairs(robot.executor.tasks) do

        if task.executed then
            msg = msg .. "[" .. task.executed .. "]\r\n"
        end

        if task.stage ~= nil then
            msg = msg .. " " .. task.stage
        end

        msg = msg .. " [" .. (vm_names[task.type] or task.type) .. "]"

        if task.name ~= nil then
            msg = msg .. " " .. task.name
        end

        if task.weight ~= nil then
            msg = msg .. " 重量" .. formatFloat(task.weight) .. "g"
        end

        if task.start_weight and task.end_weight then
            msg = msg .. " 电子秤(" .. formatFloat(task.start_weight) .. "-" .. formatFloat(task.end_weight) .. ")"
        end

        if task.distance then
            msg = msg .. " 距离" .. formatFloat(task.distance) .. "cm"
        end

        if task.start_position and task.end_position then
            msg = msg .. " 位置(" .. formatFloat(task.start_position) .. "-" .. formatFloat(task.end_position) .. ")"
        end

        if task.speed ~= nil then
            msg = msg .. " 速度" .. formatFloat(task.speed)
        end

        if task.level ~= nil then
            msg = msg .. " 等级" .. task.level
        end

        if task.time ~= nil then
            msg = msg .. " 时间" .. task.time .. "ms"
        end

        msg = msg .. "\r\n"
    end
    return msg
end

local function onFeedFinished(ctx)
    log.info("onFeedFinished 下料圈数", ctx.feed_rounds, sensor.feed_rounds)
    -- log.info("onFeedFinished 重量", ctx.weights[1], ctx.weights[2], ctx.weights[3], ctx.weights[4])

    -- 记录并计算总重
    local total = 0
    if options.smart then
        for i = 1, 4, 1 do
            local w = ctx.weights and ctx.weights[i] or 0
            if w and w > 0 then
                current_plans[#current_plans][i].final_weight = w
                total = total + w
            else
                current_plans[#current_plans][i].final_weight = 0
            end
        end
    end

    -- 智能模式，计算并更新绞龙下料量
    if options.smart and total > 0 and ctx.feed_rounds and ctx.feed_rounds > 0 then

        -- 更新每圏重量
        local weight_per_round = total / ctx.feed_rounds

        -- 避免过大过小，可以参数化
        if weight_per_round > settings.device.weight_per_round_max then
            weight_per_round = settings.device.weight_per_round_max
        end
        if weight_per_round < settings.device.weight_per_round_min then
            weight_per_round = settings.device.weight_per_round_min
        end

        feeder.weight_per_round = weight_per_round
        -- log.info("weight_per_round", weight_per_round)           
    end

    iot.emit("log", "###投喂结束 日志：\r\n" .. feedLog())

    iot.emit("log", "投喂结束：\r\n" .. planLog())

    -- 如果未结束，则下一轮，结束则汇总上传
    if current_food.ranks > #current_plans then
        log.info("本轮任务结束")
        -- local tm = current_food.interval * 60 * 1000
        -- iot.setTimeout(robot.feed_rank, tm)
        return
    end

    -- 判断重量是否达标
    if options.smart then
        local lack = false
        local total_lack = 0
        for i = 1, 4, 1 do
            local weight = current_weights[i]
            for j, plan in ipairs(current_plans) do
                weight = weight - (plan[i].final_weight or 0)
            end

            -- 未达标
            if weight > 0 then
                log.info(i .. "棚喂料未达标，缺少" .. weight)
                iot.emit("log", i .. "棚喂料未达标，缺少" .. weight)
                lack = true
                total_lack = total_lack + weight
            end
        end

        if lack then
            -- 最后一趟判断，并启用补偿
            if current_food.ranks == #current_plans then

                if total_lack > 50 then
                    log.info("启用重量补偿")
                    iot.emit("log", "启用重量补偿")
                    next_feed_time = os.time() + 20 -- 20秒后开始补偿
                    return
                end

            else
                -- 补偿之后，还不到位
                if total_lack > (settings.correct.weight_error or 100) then

                    -- TODO 产生报警 event，电话报警
                    iot.emit("error", "喂料未达标，电话报警")

                    -- 投喂异常了
                    feeder.error = true
                end
            end

        end

    end

    local auto_tare = false -- 清理料桶
    local next_state = "idle" -- 下个状态

    log.info("任务全部结束")
    if options.smart and current_correct then
        if sensor.weight() < (settings.device.auto_tare_threshold or 150) then
            auto_tare = true

            -- 清理料桶
            robot.plan("auto_tare", {}, {
                branch = true,
                on_finish = function()
                    robot.state(next_state)
                end
            })
        end
    end

    -- 投喂统计
    local total_weight = 0
    for i = 1, 4, 1 do
        for j, plan in ipairs(current_plans) do
            if options.smart then
                -- 智能模式，按实际重量
                total_weight = total_weight + (plan[i].final_weight or 0)
            else
                -- 非智能模板，按目标重量
                total_weight = total_weight + (plan[i].weight or 0)
            end
        end
    end

    -- 投喂统计 保存到配置中
    local season = settings.stats.season or 1
    settings.stats["season" .. season] = (settings.stats["season" .. season] or 0) + total_weight / 1000
    settings.save("stats")

    -- 处理定时平移
    -- 只有设定有效返回时间，才平移
    log.info("定时平移", current_food.move_wait, current_food.move_back)
    if current_food.move_back ~= nil and #current_food.move_back > 0 then

        -- 定时平移等待时间
        local wait = (current_food.move_wait or 1) * 60

        -- 解析时间
        local h, m = current_food.move_back:match("(%d+):(%d+)")
        if h ~= nil and m ~= nil then
            local tm = os.date("*t")
            tm.hour = tonumber(h)
            tm.min = tonumber(m)
            tm.sec = 0

            local next = os.time(tm) - 8 * 3600 -- 减去UTC 8小时 东八区
            local now = os.time()
            -- log.info("next", next, "now", now)

            -- 距离定时平移返回时间 大于 5分钟，才执行平移
            local wait2 = next - now - wait
            log.info("定时平移等待时间", wait, wait2)

            if wait2 > 300 then

                -- 先进入平移模式
                -- robot.state("move")
                next_state = "move"

                -- 定时平移
                iot.setTimeout(function()
                    iot.emit("log", "定时平移")

                    robot.plan("move", {
                        wait = wait2
                    })
                end, wait * 1000)

                -- TODO 切换状态，定时平移也要干掉
            end
        end
    end

    -- 退出投喂状态
    if not auto_tare then
        robot.state(next_state)
    end

    -- 清空计划和任务
    current_plans = {}
    current_food = {}
end

function feeder.feed_check()
    if current_checked then
        return true
    end

    -- 使用参数指定重量
    current_weights = {current_food.pool1 * 1000, current_food.pool2 * 1000, current_food.pool3 * 1000,
                       current_food.pool4 * 1000}

    -- 非智能模式，直接检验通过
    if not options.smart then
        current_checked = true
        return true
    end

    local weight = sensor.weight()

    local total = 0
    local count = 0
    for i, v in ipairs(current_weights) do
        if v > 0 then
            total = total + v
            count = count + 1
        end
    end

    -- 小于最小投喂量
    if weight < (settings.device.feed_min or 300) * count then
        -- 自动模式，需要等待加料
        -- if not manual then
        log.info("重量不足")
        next_feed_time = os.time() + 5 * 60 -- 再等5分钟

        if wait_times < 6 then
            wait_times = wait_times + 1
            log.info("等待下一轮")
            return false, "重量不足"
        else
            -- 结束任务了
            robot.state("idle")

            -- 异常了
            feeder.error = true

            log.info("超过6次，结束投喂")
            return false, "重量不足，结束投喂"
        end
        -- end

        return false, "小于最小投喂量"
    end

    -- 检查完成
    current_checked = true

    -- 如果实时重量是一餐，或更少，则开启补偿
    if weight < total + (settings.correct.weight_correct_max or 200) then
        current_correct = true

        -- 重量不足，则平均实时重量
        if weight < total then
            for i, v in ipairs(current_weights) do
                current_weights[i] = v / total * weight
                -- 重量补偿，平均到每一趟
                -- current_weights[i] = current_weights[i] + settings.correct.weight_correct
                -- 放到最后一趟 
            end
        end
    else
        current_correct = false
    end

    return true
end

-- 投喂一轮
function feeder.feed_rank()
    local ret, info = feeder.feed_check()
    if not ret then
        return false, info
    end

    -- 计数清零
    sensor.feed_rounds = 0

    -- 创建计划（每餐调用一次）
    local tasks = feeder.plan(current_plans, current_weights, current_food.ranks or 1, current_food.board_times or 0,
        current_correct)

    iot.emit("log", "投喂计划：\r\n" .. planLog())

    if #tasks == 0 then
        log.info("无有效投喂任务")
        iot.emit("log", "无法生成有效投喂任务")

        robot.state("idle") -- 结束投喂模式
        return false, "无法生成有效投喂任务"
    end

    -- 记录下次启动时间
    next_feed_time = os.time() + (current_food.interval or 5) * 60
    log.info("下次投喂时间", os.date("%Y-%m-%d %H:%M:%S", next_feed_time))

    return true, {
        tasks = tasks,
        on_finish = onFeedFinished
    }
end

-- 开启投喂任务
function feeder.feed(data)

    -- 找到餐食
    if not data.food then
        data.food = feeder.find_nearest_food()
        if not data.food then
            return false, "没有配置喂餐"
        end
    end

    -- 初始化投喂数据
    current_plans = {}
    current_food = settings["food" .. data.food]
    current_weights = {0, 0, 0, 0}
    current_checked = false
    wait_times = 0

    -- 重置错误状态
    feeder.error = false

    -- 开始第一轮
    return feeder.feed_rank()
end

-- 自动
function feeder.auto(v)
    if v == nil then
        return options.auto
    end
    options.auto = v
    configs.save("robot", options)

    if v then
        feeder.start()
    else
        feeder.stop()
    end
end

-- 智能
function feeder.smart(v)
    if v == nil then
        return options.smart
    end
    options.smart = v
    configs.save("robot", options)
end

function feeder.start()

    -- 启动定时任务
    if options.auto then
        -- 创建计划任务
        for i = 1, 8, 1 do
            local name = "food" .. i
            local food = settings[name]
            if food.enable then
                schedule.clock(food.start, function()
                    if not options.auto then
                        return
                    end

                    -- 直接进入投喂模式
                    robot.state("feed")

                    -- 启动计划
                    local ret, info = robot.plan("feed", {
                        food = i
                    })
                    if not ret then
                        log.info(tag, "投喂失败", info)
                        iot.emit("log", "定时投喂启动失败：" .. info)
                    end
                end)
            end
        end
    end

    -- 自动去皮
    if options.smart and settings.weight.auto_tare then
        schedule.clock(settings.weight.auto_tare_time or "03:00", function()
            if sensor.weight() < (settings.weight.auto_tare_threshold or 300) then

                if robot.state_name() ~= "charge" or robot.state_name() ~= "move" then
                    return
                end
                if components.move_servo.running then
                    return
                end

                -- 先关闭风干模式
                local ret = robot.kill("dry")

                -- 开始去皮
                robot.plan("auto_tare", {}, {
                    branch = true,
                    on_finish = function()
                        -- 恢复风干
                        if ret then
                            robot.plan("dry", {}, {
                                branch = true
                            })
                        end
                    end
                })
            end
        end)
    end

    -- 自动重启
    if settings.device.auto_reboot_enable then
        schedule.clock(settings.device.auto_reboot_time or "01:00", function()
            log.info("auto reboot")
            iot.reboot()
        end)
    end

    -- 进入待机状态
    robot.state("idle")
end

function feeder.stop()
    -- 停止定时任务
    schedule.clear()
end

-- 电子秤自动修正
function feeder.auto_correct()

    local weight = sensor.weight()
    local weight_start = sensor.weight()
    local weight_last = weight_start

    -- 开始自动修正
    log.info("start auto correct weight", weight_start)

    local wait_stable = true -- 等待稳定
    local wait_stable_ticks = 1 -- 60秒稳定时间
    local wait_correct_ticks = 1 -- 修正时间间隔s

    while true do
        iot.sleep(1000) -- 每秒检查一次

        -- 非智能模式，空转
        if not options.smart then
            goto continue
        end

        weight = sensor.weight()

        -- 投喂中，跳过
        if robot.state_name() == "feed" then
            wait_stable = true
            wait_stable_ticks = 1
            wait_correct_ticks = 1
            goto continue
        end

        -- 移动中，跳过
        if components.move_servo.running then
            wait_stable = true
            wait_stable_ticks = 1
            wait_correct_ticks = 1
            goto continue
        end

        -- 等待稳定
        if wait_stable then
            if wait_stable_ticks < 60 then
                if math.abs(weight - weight_last) < 30 then
                    wait_stable_ticks = wait_stable_ticks + 1
                else
                    wait_stable_ticks = 1
                end
                goto continue
            end
            wait_stable = false

            weight_start = weight -- 稳定后的重量
            log.info("weight stable", weight_start)
        end

        -- 重量变化过大，重新等待
        if math.abs(weight - weight_last) > 30 then
            wait_stable = true
            wait_stable_ticks = 1
            wait_correct_ticks = 1
            goto continue
        end

        -- 等待修正时间
        if wait_correct_ticks < (settings.weight.zero_correct_interval or 10) then
            wait_correct_ticks = wait_correct_ticks + 1
            goto continue
        end
        wait_correct_ticks = 1

        log.info("auto correct weight", weight_start, weight)

        -- 开始修正
        if weight_start < 0 then
            -- 负数修正
            if weight_start > -(settings.weight.negative_correct_threshold or 300) then
                -- 零点修正
                log.info("zero correct weight", weight_start, weight)
                sensor.correct(0, settings.weight.correct_threshold or 10)
            end
        else
            if weight_start < (settings.weight.zero_correct_threshold or 100) then
                -- 零点修正
                log.info("zero correct weight", weight_start, weight)
                sensor.correct(0, settings.weight.correct_threshold or 10)
            else
                -- 满量程修正
                log.info("full correct weight", weight_start, weight)
                sensor.correct(weight_start, settings.weight.correct_threshold or 10)
            end
        end

        ::continue::
        weight_last = weight
    end
end

local function is_job(job)
    return robot.executor and (robot.executor.job == job)
end

-- 更新状态
function feeder.update_status()
    while true do
        iot.sleep(1000) -- 每秒检查一次

        master.device:put_values({
            charging = battery.charging,
            charge_current = battery.charge_current(),
            usage_current = battery.usage_current(),
            voltage = battery.voltage(),
            battery = battery.percent(),
            position = sensor.position() / 100,
            weight = sensor.weight() / 1000,
            move_speed = robot.executor and robot.executor.context.move_speed,
            feed_speed = robot.executor and robot.executor.context.feed_speed,
            forward_limit = components.forward_limit.gpio:get() == 0,
            backward_limit = components.backward_limit.gpio:get() == 0,
            meg_sensor = components.meg_sensor.gpio:get() == 0,
            -- move_alarm = convert_down_gpio(limit.move_alarm:get(),)
            -- feed_alarm = convert_down_gpio(limit.feed_alarm:get(),)
            weight_per_round = feeder.weight_per_round,
            auto = options.auto,
            smart = options.smart,
            dry = settings.dry.enable,
            moving_forward = is_job("move_forward"),
            moving_backward = is_job("move_backward"),
            feeding_forward = components.feed_servo.rounds > 0,
            feeding_backward = components.feed_servo.rounds < 0,
            faning = components.fan.pwm ~= nil,
            clearing = is_job("auto_tare"),
            forward_limit_enable = settings.device.forward_limit_enable,
            backward_limit_enable = settings.device.backward_limit_enable,
            meg_sensor_enable = settings.device.meg_sensor_enable,
            feed_rounds = sensor.feed_rounds,
            job = robot.executor and robot.executor.job,
            feeding = is_job("feed"),
            moving = is_job("move"),
            mode = robot.fsm.state.name,
            error = robot.state_name() == "error",
            ranks = #current_plans,
            stats = settings.stats["season" .. (settings.stats.season or 1)] or 0
        })
    end
end

-- 打开
function feeder.open()

    -- 规整数据
    feeder.normalize()

    -- 启动定时任务
    feeder.start()

    -- 自动修正
    iot.start(feeder.auto_correct)

    -- 上报状态
    iot.start(feeder.update_status)
end

-- 关闭
function feeder.close()
    feeder.stop()
end

-- 所有参数
local names = { --
"device", -- 设备参数 行进电机，下料电机，风机
"weight", -- 重量参数 自动去皮，零点校准，满点校准
"encoder", -- 编码器参数 脉冲数
"correct", -- 偏差设置
"feed", -- 投喂参数
"dry", -- 风干参数
"distance", -- 距离设置
"food1", "food2", "food3", "food4", "food5", "food6", "food7", "food8", -- 餐1-8
"stats", -- 统计
"functions" -- 功能开关
}
for i, v in ipairs(names) do
    settings.register(v)
end

feeder.deps = {"components", "settings", "robot"}

-- 注册
boot.register("feeder", feeder)

return feeder
