local log = iot.logger("events")

local settings = require("settings")
local feeder = require("feeder")
local sensor = require("sensor")
local robot = require("robot")

iot.on("FEED_SENSOR", function(level)
    log.info("FEED_SENSOR", level)
    if level == 0 then
        sensor.feed_rounds = sensor.feed_rounds + 1
    end
end)

iot.on("FEED_BUTTON", function(state)
    log.info("FEED_BUTTON", state)
    iot.emit("log", "按钮操作：一键投喂")
    if robot.state_name() ~= "feed" then
        robot.plan("feed")
    end
end)

iot.on("MOVE_BUTTON", function(state)
    log.info("MOVE_BUTTON", state)
    iot.emit("log", "按钮操作：一键平移")
    robot.plan("move")
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
