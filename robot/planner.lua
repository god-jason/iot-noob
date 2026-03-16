--- 计划管理器
-- @module planners
local planners = {}

local planner = {}
local log = iot.logger("planner")
local utils = require("utils")

--[[
计划器参考
function(params)
    if not ok then
        return false, "未准备好"
    end
    return true, {{type:move}}
end
]] --

--- 注册计划器
function planner.register(name, fn)
    planners[name] = fn

    if type(name) == "string" and type(fn) == "function" then
        planners[name] = fn
    end

    -- 批量注册
    if type(name) == "table" then
        for k, v in pairs(name) do
            if type(v) == "function" then
                planners[k] = v
            end
        end
    end
end

--- 生成计划
-- @param name string 计算名称
-- @param data any 参数
-- @return boolean 成功与否
-- @return string|table 任务 VM格式
function planner.plan(name, data)
    local fn = planners[name]
    if not fn then
        return false, "找不到计划器"
    end

    local ret, plan = utils.call(fn, data or {})
    --log.info("plan", name, ret, res, plan)
    if not ret then
        return ret, plan
    end

    plan.job = plan.job or name
    plan.created = os.date("%Y-%m-%d %H:%M:%S") -- 记录创建时间

    return true, plan
end

return planner
