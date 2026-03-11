local log = iot.logger("commands")

local vm = require("vm")

local controls = require("controls")

function vm.move(task)
    local tm = controls.move(task.speed, task.rounds)
    return task.wait, tm
end

function vm.cam_left(task)
    local tm = controls.cam_left(task.rpm)
    return task.wait, tm
end

function vm.cam_right(task)
    local tm = controls.cam_right(task.rpm)
    return task.wait, tm
end

