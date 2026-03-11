local log = iot.logger("controls")

local controls = {}

-- 每圈的距离，直径10cm
local distance_per_round = 3.1415926535897 * 10

-- 起始速度，阶梯速度
local move_speed_start = 60
local move_speed_step = 10

-- 行走
function controls.move(speed, rounds)
    components.arm_pin:off()
    components.move_pin:on()
    -- 计算速度
    local rpm = move_speed_start + move_speed_step * (speed - 1)
    return components.move_stepper:start(rpm, rounds)
end

-- 停止行走
function controls.move_stop()
    components.move_pin:off()
    components.move_stepper:stop()
end

-- 摄像头 右转
function controls.cam_left(rpm)
    components.turn_pin:off()
    components.cam_pin:on()
    return components.cam_stepper:start(rpm, 0.75)
end

-- 摄像头 右转
function controls.cam_right(rpm)
    components.turn_pin:off()
    components.cam_pin:on()
    return components.cam_stepper:start(rpm, -0.75)
end

-- 摄像头 停止
function controls.cam_stop()
    components.cam_pin:off()
    components.cam_stepper:stop()
end

-- 左转
function controls.turn_left(rpm, dis)
    components.cam_pin:off()
    components.turn_pin:on()
    return components.turn_stepper:start(rpm, dis)
end

-- 右转
function controls.turn_right(rpm, dis)
    components.cam_pin:off()
    components.turn_pin:on()
    return components.turn_stepper:start(rpm, -dis)
end

-- 旋转 停止
function controls.turn_stop()
    components.turn_pin:off()
    components.turn_stepper:stop()
end

-- 机械臂 向上
function controls.arm_up(rpm, dis)
    components.move_pin:off()
    components.arm_pin:on()
    return components.arm_stepper:start(rpm, dis)
end

-- 机械臂 向下
function controls.arm_down(rpm, dis)
    components.move_pin:off()
    components.arm_pin:on()
    return components.arm_stepper:start(rpm, -dis)
end

-- 机械臂 停止
function controls.arm_stop()
    components.arm_pin:off()
    components.arm_stepper:stop()
end

-- 接水
function controls.water_up()
    components.water_pin1:on()
    components.water_pin2:off()
end

-- 断水
function controls.water_down()
    components.water_pin1:on()
    components.water_pin2:off()
end

return controls
