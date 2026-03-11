local actions = require("actions")
local robot = require("robot")

function actions.stop(data)
    return robot.plan("stop", data)
end

function actions.patrol(data)
    return robot.plan("patrol", data)
end

function actions.cam_angle(data)
    return robot.plan("cam_angle", data)
end

function actions.extinguish(data)
    return robot.plan("extinguish", data)
end

function actions.extinguish_stop(data)
    return robot.plan("extinguish_stop", data)
end

