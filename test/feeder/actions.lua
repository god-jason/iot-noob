local actions = require("agent").commands()

local settings = require "settings"
local controls = require "controls"
local vm = require "vm"
local sensor = require "sensor"
local robot = require "robot"
local battery = require "battery"
local feeder = require "feeder"

-- 停机
function actions.stop()
    robot.stop()
    return true
end

-- 一键平移
function actions.move(data)

    -- 结束平移
    if not data.value then
        if robot.state_name() == "move" then
            robot.executor:stop()
            robot.state("standby")
            return true
        end
        return false, "不在平移中"
    end

    if robot.state_name() == "move" then
        return false, "已经在平移中"
    end

    return robot.plan("move", data)
end

-- 一键投喂
function actions.feed(data)

    if not data.value then
        if robot.state_name() == "feed" then
            -- 取消投喂，进入维护模式
            robot.executor:stop()
            robot.state("standby")
            -- robot.state("idle")
            return true
        end
        return false, "不在投喂中"
    end

    if robot.state_name() == "feed" then
        return false, "已经在投喂中"
    end

    if not feeder.auto() then
        return false, "未开启自动模式"
    end

    if settings.total_length == 0 then
        return false, "无效棚长度"
    end

    -- 找到最近一餐
    local food = feeder.find_nearest_food()
    if not food then
        return false, "未配置有效喂餐"
    end

    data.food = food

    -- 进入投喂模式
    return robot.plan("feed", data)
end

-- 向前移动
function actions.move_forward(data)
    if not data.value then
        if robot.executor and robot.executor.job == "move_forward" then
            robot.executor:stop()
            robot.state("standby")
            return true
        end
        return false, "不在距离前进中"
    end

    if robot.state_name() == "feed" then
        return false, "正在投喂中"
    end

    if robot.executor and robot.executor.job == "move_forward" then
        return false, "已经在距离前进中"
    end

    return robot.plan("move_forward", data)
end

-- 向后移动
function actions.move_backward(data)
    if not data.value then
        if robot.executor and robot.executor.job == "move_backward" then
            robot.executor:stop()
            robot.state("standby")
            return true
        end
        return false, "不在距离后退中"
    end

    if robot.state_name() == "feed" then
        return false, "正在投喂中"
    end

    if robot.executor and robot.executor.job == "move_backward" then
        return false, "已经在距离后退中"
    end

    return robot.plan("move_backward", data)
end

-- 下料电机正转
function actions.feed_forward(data)
    if data.value then
        components.feed_servo:start(settings.feed.feed_speed or 60, 10000) -- 默认10000圈
    else
        components.feed_servo:stop()
    end
    return true
end

-- 下料电机反转
function actions.feed_backward(data)
    if data.value then
        components.feed_servo:start(settings.feed.feed_speed or 60, -10000) -- 默认10000圈
    else
        components.feed_servo:stop()
    end
    return true
end

-- 自动开关
function actions.auto(data)
    feeder.auto(data.value)
    return true
end

-- 智能模式
function actions.smart(data)
    feeder.smart(data.value)
    return true
end

-- 打开风机
function actions.fan(data)
    if data.value then
        components.fan:open(settings.feed.feed_fan_level or 7)
    else
        components.fan:close()
    end
    return true
    -- iot.setTimeout(control.fan_stop, (data.time or 10) * 1000) -- 默认10秒
end

-- 风干开关
function actions.dry(data)
    feeder.dry(data.value)
    return true
end

-- 料桶清理
function actions.clear(data)
    return robot.plan("auto_tare", data)
end

-- 去皮
function actions.tare(data)
    sensor.tare()
    return true
end

-- 校准
function actions.calibrate(data)
    sensor.calibrate((data.weight or 10) * 1000) -- 默认 10kg
    return true
end

-- 清理错误
function actions.clear_error(data)
    if robot.state_name() == "error" then
        robot.state("idle")
        return true
    else
        return false, "不在错误状态"
    end
end

-- 强制前进
function actions.force_move_forward(data)
    if data.distance == 0 then
        return false, "距离不能是0"
    end
    return robot.plan("force_move", {
        speed = data.speed or 5,
        distance = (data.distance or 1) * 100
    })
end

-- 强制后退
function actions.force_move_backward(data)
    if data.distance == 0 then
        return false, "距离不能是0"
    end
    return robot.plan("force_move", {
        speed = data.speed or 5,
        distance = -(data.distance or 1) * 100
    })
end

-- 关闭启用前接近开关
function actions.forward_limit(data)
    settings.device.forward_limit_enable = data.value
    settings.save("device")
    return true
end

-- 关闭启用后接近开关
function actions.backward_limit(data)
    settings.device.backward_limit_enable = data.value
    settings.save("device")
    return true
end

-- 关闭启用磁感应
function actions.meg_sensor(data)
    settings.device.meg_sensor_enable = data.value
    settings.save("device")
    return true
end

-- 设置当前位置
function actions.zero(data)
    -- data.position
    sensor.set_position(0)
    return true
end

-- 一键归位
function actions.home(data)
    return robot.plan("home", data)
end


-- 重启驱动器
function actions.reboot_drv(data)
    components.driver:turn_on()
    iot.setTimeout(function()
        components.driver:turn_off()
    end, (data.timeout or 5) * 1000)

    -- 重置状态
    iot.setTimeout(function()
        robot.state("idle")
    end, 10000)
end

-- 充电
function actions.charge(data)
    return robot.plan("charge", data)
end

-- 充电，只开启继电器
function actions.charge2(data)
    battery.charge(true)
    return true
end


-- 震动器启动
function actions.vibrator(data)
    return robot.plan("vibrator", data, {
        branch = true -- 独立运行
    })
end
