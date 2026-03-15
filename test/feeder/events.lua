local log = iot.logger("events")

local settings = require("settings")
local feeder = require("feeder")
local sensor = require("sensor")
local robot = require("robot")



iot.on("FORWARD_LIMIT", function(level)
    if not settings.device.forward_limit_enable then
        return
    end
    log.info("FORWARD_LIMIT", level)

    if level == 0 then
        -- 后退抖动情况，不处理
        if components.move_servo.running and components.move_servo.rounds < 0 then
            return
        end

        -- 立即停止电机
        components.move_servo:stop()

        -- 到终点时，不能移动了
        if sensor.position() < settings.total_length - (settings.correct.forward_detect or 50) then
            if robot.executor then
                robot.executor:pause()
            end
        else
            if robot.executor then
                robot.executor:interrupt()
            end
            sensor.set_position(settings.total_length)
        end
    else
        if robot.executor and robot.executor.paused then
            robot.executor:resume()
        end
    end
end)

iot.on("BACKWARD_LIMIT", function(level)
    if not settings.device.backward_limit_enable then
        return
    end
    log.info("BACKWARD_LIMIT", level)

    if level == 0 then
        -- 前进抖动情况，不处理
        if components.move_servo.running and components.move_servo.rounds > 0 then
            return
        end

        -- 立即停止电机
        components.move_servo:stop()

        if sensor.position() > (settings.correct.backward_detect or 50) then
            if robot.executor then
                robot.executor:pause()
            end
        else
            if robot.executor then
                robot.executor:interrupt()
            end
            sensor.set_position(0) -- 位置清零
        end
    else
        if robot.executor and robot.executor.paused then
            robot.executor:resume()
        end
    end

end)

iot.on("MEG_SENSOR", function(level)
    if not settings.device.meg_sensor_enable then
        return
    end
    log.info("MEG_SENSOR", level)

    if level == 0 then
        -- 前进抖动情况，不处理
        if components.move_servo.running and components.move_servo.rounds > 0 then
            return
        end

        -- 立即停止电机
        components.move_servo:stop()

        if robot.executor then
            robot.executor:interrupt()
        end

        sensor.set_position(0) -- 位置清零
        -- 如果未启用编码器，需要等VM停止，再清一次0
        -- if not settings.encoder.enable then
        --     iot.setTimeout(sensor.set_position, 1000, 0)
        -- end
    end
end)

iot.on("FEED_SENSOR", function(level)
    log.info("FEED_SENSOR", level)
    if level == 0 then
        sensor.feed_rounds = sensor.feed_rounds + 1
    end
end)

iot.on("SETTING", function(name)
    log.info("SETTING", name)
    
    if name == "distance" then
        feeder.normalize()
    elseif name:startsWith("food") or name == "weight" then
        -- 重新载入
        feeder.stop()
        feeder.start()
    end
end)
