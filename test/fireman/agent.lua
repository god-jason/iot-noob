local agent = {}
local log = iot.logger("agent")

local actions = require("actions")
local planners = require("planners")
local robot = require("robot")
local boot = require("boot")

function agent.open()
    log.info("open")

    -- 将planners 注册到 actions 中
    for k, v in pairs(planners) do
        actions[k] = function(data)
            log.info("plan", k, iot.json_encode(data))
            return robot.plan(k, data)
        end
    end

    return true
end

function agent.close()
    return true
end

agent.deps = {"robot", "settings"}

-- 注册
boot.register("agent", agent)
