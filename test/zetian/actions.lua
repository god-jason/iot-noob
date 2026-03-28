local actions = require("agent").actions()

local master = require "master"

-- 开关机
function actions.control(data)
    if data.value == false or data.value == 0 then
        return master.device:set("control", 0)
    else
        return master.device:set("control", 1)
    end
end

-- 开
function actions.open(data)
    return master.device:set("control", 1)
end

-- 关
function actions.close(data)
    return master.device:set("control", 0)
end
