local instructions = {}

local Executor = require("executor")
local components = require("components")

local log = iot.logger("instruction")

function instructions.wait(context, task)
    -- VM中监测wait_timeout并等待
end

function instructions.fan(context, task)
    components.fan.speed(task.level)
end

function instructions.move(context, task)
    local rpm = components.move_speeder:calc(task.level)
    components.move.start(rpm, task.rounds)
end

function instructions.brake(context, task)
    components.turn_stepper.brake()
end

function instructions.turn_left(context, task)
    components.turn_stepper.start(task.rpm, task.rounds)
end

function instructions.turn_right(context, task)
    components.turn_stepper.start(task.rpm, -task.rounds)

end

-- 注册指令
Executor.register(instructions)
