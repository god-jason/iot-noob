local log = iot.logger("commands")

local vm = require("vm")

-- 每圈的距离，直径10cm
local distance_per_round = 3.1415926535897 * 10

-- 起始速度，阶梯速度
local move_speed_start = 60
local move_speed_step = 10

-- 摄像头圈数
local cam_rounds = 0.75 -- 默认3/4圈，实际要按比例计算
local turn_rounds = 1 -- 要按实际圈数
local arm_rounds = 1 -- 要按实际圈数

-- 行走
function vm.move(task)
    components.arm_pin:off()
    components.move_pin:on()
    -- 计算速度
    local rpm = move_speed_start + move_speed_step * (task.speed - 1)
    return task.wait, components.move_stepper:start(rpm, task.rounds)
end

-- 停止行走
function vm.move_stop()
    components.move_pin:off()
    components.move_stepper:stop()
end

-- 摄像头 左转
function vm.cam_left(task)
    components.turn_pin:off()
    components.cam_pin:on()
    return task.wait, components.cam_stepper:start(task.rpm, -cam_rounds)
end

-- 摄像头 右转
function vm.cam_right(task)
    components.turn_pin:off()
    components.cam_pin:on()
    return task.wait, components.cam_stepper:start(task.rpm, cam_rounds)
end

-- 摄像头 转到 指定角度
function vm.cam_angle(task)
    components.turn_pin:off()
    components.cam_pin:on()
    local rounds = cam_rounds * (task.angle - 135) / 270
    return task.wait, components.cam_stepper:start(task.rpm, rounds)
end

-- 摄像头 停止
function vm.cam_stop(task)
    components.cam_pin:off()
    components.cam_stepper:stop()
end

-- 旋转返回
function vm.turn_back(task)
    components.cam_pin:off()
    components.turn_pin:on()
    if task.angle then
        local rounds = turn_rounds * task.angle / 360
        return task.wait, components.turn_stepper:start(task.rpm, -rounds)
    else
        return task.wait, components.turn_stepper:start(task.rpm, -(turn_rounds))
    end
end

-- 转到 指定角度
function vm.turn_angle(task)
    components.cam_pin:off()
    components.turn_pin:on()
    local rounds = turn_rounds * task.angle / 360
    return task.wait, components.turn_stepper:start(task.rpm, rounds)
end

-- 旋转 停止
function vm.turn_stop()
    components.turn_pin:off()
    components.turn_stepper:stop()
end

-- 机械臂 旋转返回
function vm.arm_back(task)
    components.move_pin:off()
    components.arm_pin:on()
    if task.angle then
        local rounds = arm_rounds * task.angle / 180
        return task.wait, components.arm_stepper:start(task.rpm, -rounds)
    else
        return task.wait, components.arm_stepper:start(task.rpm, -arm_rounds)
    end
end

-- 机械臂 转到 指定角度
function vm.arm_angle(task)
    components.move_pin:off()
    components.arm_pin:on()
    local rounds = arm_rounds * task.angle / 180
    return task.wait, components.arm_stepper:start(task.rpm, rounds)
end

-- 机械臂 停止
function vm.arm_stop()
    components.arm_pin:off()
    components.arm_stepper:stop()
end

-- 接水
function vm.water_up(task)
    components.water_pin1:on()
    components.water_pin2:off()
    return task.wait, 1000
end

-- 断水
function vm.water_down(task)
    components.water_pin1:off()
    components.water_pin2:on()
    return task.wait, 1000
end

-- 停止接水
function vm.water_stop()
    components.water_pin1:off()
    components.water_pin2:off()
end
