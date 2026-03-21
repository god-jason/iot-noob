local log = iot.logger("controls")

local vm = require("vm")
local sensor = require("sensor")
local settings = require("settings")
local feeder = require("feeder")
local robot = require("robot")

-- 启动风机
function vm.fan(task, ctx, executor)
    ctx.fan_level = task.level
    components.fan:speed(task.level)
end

-- 停止风机
function vm.fan_stop(task, ctx, executor)
    ctx.fan_level = nil
    components.fan:close()
end

-- 震动
function vm.vibrator(task, ctx, executor)
    ctx.vibrator = true
    components.vibrator:on()
end

-- 震动停止
function vm.vibrator_stop(task, ctx, executor)
    ctx.vibrator = false
    components.vibrator:off()
end

-- 移动
function vm.move(task, ctx, executor)
    ctx.move_task = task
    ctx.move_speed = task.speed

    task.start_position = sensor.position() -- 记录起始位置

    -- 如果限位开关已经触发，则不执行了，直接到move_end
    -- if task.distance > 0 then
    --     -- 到终点时，不能移动了
    --     if settings.device.forward_limit_enable and components.forward_limit.gpio:get() == 0 then
    --         return
    --     end
    -- else
    --     -- 到起点时，不能移动了
    --     if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
    --         return
    --     end
    --     if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
    --         return
    --     end
    -- end

    -- local tm = control.move(task.speed, task.rounds)

    local rpm = feeder.calc_move_rpm(task.speed)
    local tm = feeder.calc_move_time(rpm, task.distance) -- TODO 此处没有计算加速时间

    -- log.info("move time", tm)
    task.time = tm

    -- 处理恢复的移动任务
    if task.final_time ~= nil and task.final_time < tm then
        local tm2 = tm - task.final_time -- 减去上次的时间
        task.start_ticks = mcu.ticks() - task.final_time -- 向前推进一个假时间，方便计算
        tm = components.move_servo:start(rpm, task.rounds * tm2 / tm) -- 按比例行进
    else
        task.start_ticks = mcu.ticks()
        tm = components.move_servo:start(rpm, task.rounds)
    end

    -- TODO 加速距离没有计算

    -- 进度检查
    if not settings.encoder.enable then
        iot.start(function()
            local start = mcu.ticks()

            -- 1s后再计算
            iot.sleep(100)

            while task == ctx.move_task and not executor.stoped and not executor.paused do

                -- 计算用时
                local tick = mcu.ticks()
                local tm3 = tick - start
                start = tick

                -- 计算距离
                local dis = feeder.calc_move_distance(rpm * tm3 / 60000)

                -- 如果未开编码器，则定时设置距离
                if task.distance > 0 then
                    sensor.add_position(dis)
                else
                    sensor.add_position(-dis)
                end

                iot.sleep(100)

            end
        end)
    end

    -- 检查限位开关
    iot.setTimeout(function()
        if task == ctx.move_task and not executor.stoped and not executor.paused then

            if task.distance > 0 then

                -- 向前行走，开关没有松开
                if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
                    executor:stop()
                    robot.state("error", "后接近开关故障")
                    return
                end
                if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
                    executor:stop()
                    robot.state("error", "后磁感应开关故障")
                    return
                end

            else
                -- 向后行走，开关没有松开
                if settings.device.forward_limit_enable and components.forward_limit.gpio:get() == 0 then
                    executor:stop()
                    robot.state("error", "前接近开关故障")
                    return
                end
            end

        end

    end, 3000) -- 3s后再计算

    -- 主动上报数据
    iot.emit("report")

    return task.wait, tm
end

-- 移动结束
function vm.move_end(task, ctx, executor)
    if not ctx.move_task then
        return
    end

    -- 已经到终点或起点，end任务就不再执行了
    if ctx.move_task.distance > 0 then
        -- 到终点时，不能移动了
        if settings.device.forward_limit_enable and components.forward_limit.gpio:get() == 0 then
            return
        end
    else
        -- 到起点时，不能移动了
        if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
            return
        end
        if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
            return
        end
    end

    -- 编码器启用，任务未结束，开启位置补偿
    if settings.encoder.enable and settings.encoder.correct and executor and not executor.paused and not executor.stoped then
        local diff = ctx.move_task.start_position + ctx.move_task.distance - sensor.position()
        local d = settings.encoder.correct_distance or 20

        if (ctx.move_task.distance > 0 and diff > d) or (ctx.move_task.distance < 0 and diff < -d) then
            task.error = "行走不到位，还差" .. diff .. "cm"

            local times = 1
            while (ctx.move_task.distance > 0 and diff > d) or (ctx.move_task.distance < 0 and diff < -d) do

                -- 至多补偿3次
                if times > 3 then
                    break
                end

                iot.emit("log", "行走不到位，还差" .. diff .. "cm" .. "，补偿第" .. times .. "次")

                local rpm = feeder.calc_move_rpm(ctx.move_task.speed)
                local rounds = feeder.calc_move_rounds(diff)

                -- 执行补偿
                local tm = components.move_servo:start(rpm, rounds)
                local ret = executor:wait(tm)
                if ret then
                    -- 补外部中断，则停止
                    -- components.move_servo:stop()
                    return
                end

                diff = ctx.move_task.start_position + ctx.move_task.distance - sensor.position()
                times = times + 1
            end

            -- 停止电机
            -- components.move_servo:stop()

            -- 补偿仍不到位
            if (ctx.move_task.distance > 0 and diff > d) or (ctx.move_task.distance < 0 and diff < -d) then
                iot.emit("log", "行走不到位，补偿失败，还差" .. diff .. "cm")

                -- TODO 如果差值较大，则报警，停机
            end
        end

    end

    -- 最终位置回写
    if not settings.encoder.enable then
        if task.position then
            sensor.set_position(task.position)
        end
    end

    -- 运行速度置零
    ctx.move_speed = 0
    ctx.move_task.final_time = mcu.ticks() - ctx.move_task.start_ticks

    ctx.move_task.end_position = sensor.position()
    ctx.move_task.final_distance = ctx.move_task.end_position - ctx.move_task.start_position
    ctx.move_task = nil -- 指令结束，清空
end

-- 停止移动
function vm.move_stop(task, ctx, executor)
    components.move_servo:stop()
    vm.move_end(task, ctx, executor)
end

-- 锁机
function vm.move_lock(task, ctx, executor)
    components.move_servo:move_lock()
end

-- 刹车
function vm.brake(task, ctx, executor)
    components.move_servo:brake()

    -- 位置回写
    if not settings.encoder.enable then
        if task.position then
            sensor.set_position(task.position)
        end
    end

    -- 刹车 一般是棚结束
    -- 主动上报数据
    iot.emit("report")
end

-- 位置清零
function vm.zero(task, ctx, executor)
    -- 主动上报数据
    iot.emit("report")

    -- 都禁用了，则不检查，直接归零
    -- if not settings.device.backward_limit_enable and not settings.device.meg_sensor_enable then
    --     components.move_servo:stop()
    --     sensor.set_position(0)
    --     return
    -- end

    -- 再减速逼近起点，直到-100cm，实现归零
    local rpm = feeder.calc_move_rpm(task.speed or 2)
    local distance = -math.abs(task.distance or 100)
    local rounds = feeder.calc_move_rounds(distance)

    local success = false

    -- 至多清零5次
    for i = 1, 5, 1 do

        log.info("第" .. i .. "次位置清零")
        iot.emit("log", "第" .. i .. "次位置清零")
        -- agent.watch() -- 实时上传位置

        -- 向前推进
        local tm = components.move_servo:start(rpm, rounds)

        -- 调用执行器的等待（反向调用了，有点怪）
        local ret = executor:wait(tm)
        if ret then
            -- 已经有后接近信号了
            if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
                iot.emit("log", "后接近信号，清零成功")
                success = true
                break
            end
            if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
                iot.emit("log", "后磁感应信号，清零成功")
                success = true
                break
            end

            -- 外部触发，结束任务，可能是到起点了，也可能是被取消了
            return
        end

        -- 主动上报数据
        iot.emit("report")
    end

    -- 停止运行
    components.move_servo:stop()

    if not success then
        -- 3次都失败，则直接置零

        -- 位置清零失败
        iot.emit("log", "位置清零失败")

        -- 不能再喂了  停止任务
        robot.state("error", "位置清零失败")
        executor:stop()

        -- error("位置清零失败")
        return
    end

    log.info("清零完成", settings.device.weigh_distance)

    -- 前进几cm，让后接近信号关闭
    if settings.device.weigh_distance and settings.device.weigh_distance > 1 then
        log.info("向前移动到称重位置")

        -- 先静止
        local ret = executor:wait(1000)
        if ret then
            return
        end

        -- 前移
        local rpm = feeder.calc_move_rpm(1)
        local distance = settings.device.weigh_distance
        local rounds = feeder.calc_move_rounds(settings.device.weigh_distance)

        local tm = components.move_servo:start(rpm, rounds)
        local ret = executor:wait(tm)
        if ret then
            return
        end

        components.move_servo:brake()
    end

end

-- 投喂
function vm.feed(task, ctx, executor)
    ctx.feed_task = task

    task.start_weight = sensor.weight() -- 记录起始重量

    ctx.feed_speed = task.speed

    -- local tm = control.feed(task.speed, task.rounds)
    local tm = feeder.calc_feed_time(task.speed, task.weight)
    task.time = tm

    -- 处理恢复的移动任务
    if task.final_time ~= nil and task.final_time < tm then
        local tm2 = tm - task.final_time -- 减去上次的时间
        task.start_ticks = mcu.ticks() - task.final_time -- 向前推进一个假时间，方便计算        
        components.feed_servo:start(task.speed, task.rounds * tm2 / tm) -- 按比例投喂
        tm = tm2
    else
        ctx.feed_rounds = (ctx.feed_rounds or 0) + task.rounds -- 累计圈数
        task.start_ticks = mcu.ticks()
        components.feed_servo:start(task.speed, task.rounds)
    end

    -- 主动上报数据
    iot.emit("report")

    return task.wait, tm
end

-- 投喂结束
function vm.feed_end(task, ctx, executor)
    if not ctx.feed_task then
        return
    end

    ctx.feed_speed = 0
    ctx.feed_task.end_weight = sensor.weight()
    ctx.feed_task.final_time = mcu.ticks() - ctx.feed_task.start_ticks
    ctx.feed_task.final_weight = ctx.feed_task.end_weight - ctx.feed_task.start_weight
    ctx.feed_task = nil -- 指令结束，清空
end

-- 停止投喂
function vm.feed_stop(task, ctx, executor)
    components.feed_servo:stop()
    vm.feed_end(task, ctx, executor)
end

-- 称重
function vm.weigh(task, ctx, executor)
    local weight = sensor.weight()
    task.weight = weight

    -- 避免为空
    if not ctx.weights then
        ctx.weights = {}
    end

    -- 记录到每个阶段
    if task.pool and task.pool > 0 and ctx.weight then
        -- vm.plans[#vm.plans][task.pool].final_weight = weight - vm.weight
        ctx.weights[task.pool] = ctx.weight - weight
    end

    ctx.weight = weight
end

-- 去皮
function vm.tare(task)
    sensor.tare()

    -- 主动上报数据
    iot.emit("report")

    return task.wait, task.time or 5000
end

-- 创建支线任务
function vm.plan(task, ctx)
    robot.plan(task.name, task.data, {
        branch = true
    })
end

-- 上报消息
function vm.report(task)
    iot.emit("report", task.all)
end

-- 记录日志
function vm.log(task)
    iot.emit("log", task.data)
end

-- 停止，内部调用
function vm.stop(task, ctx, executor)
    -- TODO 直接停止会影响其他任务
    -- components.move_servo:stop()
    -- components.feed_servo:stop()
    -- components.fan:close()
    -- components.vibrator:off()

    if ctx.move_task then
        vm.move_stop(task, ctx, executor)
    end
    if ctx.feed_task then
        vm.feed_stop(task, ctx, executor)
    end
    if ctx.fan_level then
        vm.fan_stop(task, ctx, executor)
    end
    if ctx.vibrator then
        vm.vibrator_stop(task, ctx, executor)
    end

    -- 主动上报数据
    iot.emit("report")
end

function vm.pause(task, ctx, executor)
    -- TODO 直接停止会影响其他任务
    -- components.move_servo:stop()
    -- components.feed_servo:stop()
    -- components.fan:close()
    -- components.vibrator:off()

    if ctx.move_task then
        vm.move_stop(task, ctx, executor)
    end
    if ctx.feed_task then
        vm.feed_stop(task, ctx, executor)
    end
    if ctx.fan_level then
        vm.fan_stop(task, ctx, executor)
    end
    if ctx.vibrator then
        vm.vibrator_stop(task, ctx, executor)
    end

    -- 主动上报数据
    iot.emit("report")
end

-- 恢复，内部调用
function vm.resume(task, ctx, executor)
    if ctx.fan_level then
        components.fan:speed(ctx.fan_level)
    end
    if ctx.vibrator then
        components.vibrator:on()
    end
    if ctx.move_task then
        if task.type ~= "move" then
            -- 恢复行走
            vm.move(ctx.move_task, ctx, executor)
        end
    end
    if ctx.feed_task then
        if task.type ~= "feed" then
            -- 恢复投喂
            vm.feed(ctx.feed_task, ctx, executor)
        end
    end

    -- 主动上报数据
    iot.emit("report")
end
