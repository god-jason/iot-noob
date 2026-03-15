local taojingchi = require("taojingchi")
local settings = require("settings")
local sensor = require("sensor")
local battery = require("battery")
local robot = require("robot")
local feeder = require("feeder")

taojingchi.register("lock", {
    enter = function()
        taojingchi.set_text("sn", mobile.imei())
    end
})

taojingchi.register("home", {
    tick = function()        
        taojingchi.set_value("csq", mobile.csq())
        taojingchi.set_value("battery", battery.percent())
        taojingchi.set_value("weight", math.floor(sensor.weight() / 10))
        taojingchi.set_value("position", sensor.position())
        taojingchi.set_value("speed", robot.executor and robot.executor.context.move_speed)
        taojingchi.set_value("feed_weight", feeder.weight_per_round * 100)
        taojingchi.set_value("rank", robot.ranks())
        taojingchi.set_value("stats", settings.stats["season" .. (settings.stats.season or 1)] or 0)
        taojingchi.set_text("version", VERSION)
    end
})

taojingchi.register("control", {
    tick = function()
        taojingchi.set_bool("feed_forward", components.feed_servo.rounds > 0)
        taojingchi.set_bool("feed_backward", components.feed_servo.rounds < 0)
        taojingchi.set_bool("fan", components.fan.pwm ~= nil)
        taojingchi.set_bool("dry", settings.dry.enable)
        taojingchi.set_bool("auto", feeder.auto())
        taojingchi.set_bool("smart", feeder.smart())
    end
})

taojingchi.register("info", {
    enter = function()
        taojingchi.set_text("imei", mobile.imei())
        taojingchi.set_text("iccid", mobile.iccid(mobile.simid()))
        taojingchi.set_text("version", VERSION)
        local scell = mobile.scell()
        if scell then
            taojingchi.set_text("mccmnc", scell.mcc.. "," .. scell.mnc)
        end
    end
})