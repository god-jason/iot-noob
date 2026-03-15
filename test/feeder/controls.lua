local log = iot.logger("controls")

local vm = require("vm")
local sensor = require("sensor")
local settings = require("settings")
local feeder = require("feeder")

-- 启动风机
function vm.fan(task, ctx)
    ctx.fan_level = task.level
    components.fan:speed(task.level)
end

-- 停止风机
function vm.fan_stop(task, ctx)
    ctx.fan_level = nil
    components.fan:close()
end

-- 震动
function vm.vibrator(task, ctx)
    ctx.vibrator = true
    components.vibrator:on()
end

-- 震动停止
function vm.vibrator_stop(task, ctx)
    ctx.vibrator = false
    components.vibrator:off()
end

-- 移动
function vm.move(task, ctx)
    if task.distance > 0 then
        -- 到终点时，不能移动了
        if not task.force and sensor.position() > settings.total_length - 10 then
            return
        end
        if settings.device.forward_limit_enable and components.forward_limit.gpio:get() == 0 then
            return
        end
    else
        -- 到起点时，不能移动了
        if not task.force and sensor.position() < 10 then
            return
        end
        if settings.device.backward_limit_enable and components.backward_limit.gpio:get() == 0 then
            return
        end
        if settings.device.meg_sensor_enable and components.meg_sensor.gpio:get() == 0 then
            return
        end
    end

    ctx.move_task = task
    ctx.move_speed = task.speed

    task.start_position = sensor.position() -- 记录起始位置

    -- local tm = control.move(task.speed, task.rounds)

    local rpm = feeder.calc_move_rpm(task.speed)
    local tm = feeder.calc_move_time(rpm, task.distance) -- 此处没有计算加速时间
    -- log.info("move time", tm)
    task.time = tm

    -- 处理恢复的移动任务
    if task.final_time ~= nil and task.final_time < tm then
        local tm2 = tm - task.final_time -- 减去上次的时间
        ctx.start_ticks = mcu.ticks() - task.final_time -- 向前推进一个假时间，方便计算
        tm = components.move_servo:start(rpm, task.rounds * tm2 / tm) -- 按比例行进
    else
        ctx.start_ticks = mcu.ticks()
        ctx = components.move_servo:start(rpm, task.rounds)
    end

    return task.wait, tm
end

local function __move_end()
    -- 电机结束后，记录位置
    log.info("move wait", tm)

    -- iot.sleep(tm)
    local ret = iot.wait("VM_BREAK", tm)
    -- log.info("move end", ret, iot.json_encode(task))

    -- 补偿距离，执行完，且编码器打开
    if not ret and settings.encoder and settings.encoder.enable and task.position ~= nil then
        local dis = task.position - sensor.position()
        if dis > 10 then
            iot.emit("device_log", "行走不到位，补偿" .. dis .. "cm")

            -- 补偿距离
            local rnds = feeder.calc_move_rounds(dis)
            tm = components.move_servo:start(rpm, rnds)

            ret = iot.wait("VM_BREAK", tm)
            if not ret then

                -- 补偿之后，还不到位
                dis = task.position - sensor.position()
                if dis > 10 then
                    vm.stop()

                    iot.emit("device_log", "行走不到位，误差" .. dis .. "cm")

                    -- TODO 电话报警

                    -- TODO 修改状态，暂停工作
                    iot.emit("error", "行走不到位", true)
                end
            end
        end
    end
end

-- 移动结束
function vm.move_end(task, ctx)
    if not ctx.move_task then
        return
    end

    -- TODO 位置补偿

    -- 运行速度置零
    ctx.move_speed = 0
    ctx.move_task.final_time = mcu.ticks() - ctx.start_ticks

    -- 无编码器时，暂停或结束时，需要计算位置
    if not settings.encoder.enable then
        local distance = ctx.move_task.distance * ctx.move_task.final_time / ctx.move_task.time
        local position = ctx.move_task.start_position + distance
        sensor.set_position(position)
    end

    ctx.move_task.end_position = sensor.position()
    ctx.move_task.final_distance = ctx.move_task.end_position - ctx.move_task.start_position
    ctx.move_task = nil -- 指令结束，清空
end

-- 停止移动
function vm.move_stop(task, ctx)
    components.move_servo:stop()
    vm.move_end(task, ctx)
end

-- 锁机
function vm.move_lock()
    components.move_servo:move_lock()
end

-- 刹车
function vm.brake(task)
    components.move_servo:brake()
end

-- 投喂
function vm.feed(task, ctx)
    ctx.feed_task = task

    task.start_weight = sensor.weight() -- 记录起始重量

    ctx.feed_speed = task.speed
    -- local tm = control.feed(task.speed, task.rounds)
    local tm = feeder.calc_feed_time(task.speed, task.weight)
    task.time = tm

    -- 处理恢复的移动任务
    if task.final_time ~= nil and task.final_time < tm then
        local tm2 = tm - task.final_time -- 减去上次的时间
        ctx.start_ticks = mcu.ticks() - task.final_time -- 向前推进一个假时间，方便计算        
        components.feed_servo:start(task.speed, task.rounds * tm2 / tm) -- 按比例投喂
        tm = tm2
    else
        ctx.feed_rounds = (ctx.feed_rounds or 0) + task.rounds -- 累计圈数
        ctx.start_ticks = mcu.ticks()
        components.feed_servo:start(task.speed, task.rounds)
    end

    return task.wait, tm
end

-- 投喂结束
function vm.feed_end(task, ctx)
    if not ctx.feed_task then
        return
    end

    ctx.feed_speed = 0
    ctx.feed_task.end_weight = sensor.weight()
    ctx.feed_task.final_time = mcu.ticks() - ctx.start_ticks
    ctx.feed_task.final_weight = ctx.feed_task.end_weight - ctx.feed_task.start_weight
    ctx.feed_task = nil -- 指令结束，清空
end

-- 停止投喂
function vm.feed_stop(task, ctx)
    components.feed_servo:stop()
    vm.feed_end(task, ctx)
end

-- 称重
function vm.weigh(task, ctx)
    local weight = sensor.weight()
    task.weight = weight

    -- 避免为空
    if not ctx.weights then
        ctx.weights = {}
    end

    -- 记录到每个阶段
    if task.stage and task.stage > 0 and ctx.weight then
        -- vm.plans[#vm.plans][task.stage].final_weight = weight - vm.weight
        ctx.weights[task.stage] = ctx.weight - weight
    end

    ctx.weight = weight
end

-- 上报消息
function vm.report(task)
    iot.emit("report")
end

-- 停止，内部调用
function vm.stop(task, ctx)
    if ctx.move_task then
        vm.move_stop()
    end
    if ctx.move_task then
        vm.feed_stop()
    end
    if ctx.fan_level then
        vm.fan_stop()
    end
    if ctx.vibrator then
        vm.vibrator_stop()
    end
end

-- 恢复，内部调用
function vm.resume(task, ctx)
    if ctx.fan_level then
        components.fan:speed(ctx.fan_level)
    end
    if ctx.vibrator then
        components.vibrator:on()
    end
    if ctx.move_task then
        if task.type ~= "move" then
            vm.move(task, ctx)
        end
    end
    if ctx.feed_task then
        if task.type ~= "feed" then
            vm.feed(task, ctx)
        end
    end
end
