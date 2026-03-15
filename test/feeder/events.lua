local settings = require("settings")
local smart = require("smart")

iot.on("FORWARD_LIMIT", function(level)
    if not settings.device.forward_limit_enable then
        return
    end

    -- TODO 

end)

iot.on("BACKWARD_LIMIT", function(level)
    if not settings.device.backward_limit_enable then
        return
    end

    -- TODO 

end)

iot.on("MEG_SENSOR", function(level)
    if not settings.device.meg_sensor_enable then
        return
    end

    -- TODO 

end)

iot.on("SETTING", function(name)
    if name == "distance" then
        smart.normalize()
    elseif name:startsWith("food") or name == "weight" then
        -- TODO 重新重启robot
    end
end)
