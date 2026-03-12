--- 编程
-- @module program
local program = {}
local log = iot.logger("program")

local configs = require("configs")

local vm = require("vm")
local agent = require("agent")
local planner = require("planner")
local robot = require("robot")
local boot = require("boot")

-- 创建指令
local function create_instruction(name, script)
    if type(script) == "function" then
        vm[name] = script
        return true
    end

    log.info("create instruction", name, script)

    -- 封装为闭包
    script = "return function(context, task)\n" .. script .. "\nend"

    local ret, info = load(script, "instruction_" .. name, "bt", _G)
    if not ret then
        -- log.info("compile instruction error", fn)
        return false, info
    end

    -- 返回闭包
    ret, info = pcall(ret)
    if not ret then
        -- log.info("closure instruction error", fn)
        return false, info
    end

    -- 注册到虚拟机上
    vm[name] = info
    return true
end

-- 创建计划器
local function create_planner(name, script)
    if type(script) == "function" then
        planner.register(name, script)
        return true
    end

    log.info("create planner", name, script)

    -- 封装为闭包
    script = "return function(data)\n" .. script .. "\nend"

    local ret, info = load(script, "planner_" .. name, "bt", _G)
    if not ret then
        -- log.info("compile planner error", fn)
        return false, info
    end

    -- 返回闭包
    ret, info = pcall(ret)
    if not ret then
        -- log.info("closure planner error", fn)
        return ret, info
    end

    -- 注册到计划器上
    planner.register(name, info)

    -- 注册命令，远程调用
    agent.register(name, function(data)
        log.info("plan", name, iot.json_encode(data))
        return robot.plan(name, data)
    end)

    return true
end

function program.open()

    -- 加载自定义指令集
    log.info("load instructions")
    local ins = configs.load_default("instructions", {})
    for k, v in ipairs(ins) do
        local ret, info = create_instruction(v.name, v.script)
        if not ret then
            return ret, info
        end
    end

    -- 加载自定义计划器
    log.info("load planners")
    local pls = configs.load_default("planners", {})
    for k, v in ipairs(pls) do
        local ret, info = create_planner(v.name, v.script)
        if not ret then
            return ret, info
        end
    end

    return true
end

program.deps = {"settings"}

-- 注册启动
boot.register("program", program)

return program
