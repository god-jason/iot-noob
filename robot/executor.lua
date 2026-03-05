local log = iot.logger("executor")

local instructions = {}

local utils = require("utils")

-- 自增ID
local inc = utils.increment()

-- 定义实例
local Executor = {}
Executor.__index = Executor

-- 注册指令
function Executor.register(name, handler)

    if type(name) == "string" and type(handler) == "function" then
        instructions[name] = handler
    end

    -- 批量注册
    if type(name) == "table" then
        for k, v in pairs(name) do
            if type(v) == "function" then
                instructions[k] = v
            end
        end
    end
end

-- 创建实例
function Executor:new(opts)
    opts = opts or {}
    return setmetatable({
        id = inc(),
        job = opts.job or "-",
        tasks = opts.tasks or {},
        on_finish = opts.on_finish,
        on_error = opts.on_error,
        current = 1,
        context = {}
    }, Executor)
end

-- 复制实例
function Executor:clone()
    return setmetatable({
        id = inc(),
        job = Executor.job,
        tasks = Executor.tasks,
        on_finish = Executor.on_finish,
        on_error = Executor.on_error,
        current = 1,
        context = {}
    }, Executor)
end

-- 暂停
function Executor:pause()
    Executor.paused = true
    iot.emit("executor_" .. Executor.id .. "_break")
end

-- 停止
function Executor:stop()
    iot.emit("executor_" .. Executor.id .. "_break")
end

-- 执行（内部用）
function Executor:execute(cursor)
    cursor = cursor or 1 -- 默认从头开始
    log.info("execute", cursor, json.encode(Executor.tasks))

    -- 从起始任务执行
    for i = cursor, #Executor.tasks, 1 do
        local task = Executor.tasks[i]
        log.info("task", i, iot.json_encode(task))
        Executor.current = i

        local fn = instructions[task.type]
        if type(fn) == "function" then
            -- fn(task)
            local ret, info = pcall(fn, Executor.context, task)
            if not ret then
                log.error(info)
                -- 上报错误
                if not Executor.on_error then
                    Executor.on_error(info)
                end

                -- TODO 设备状态
                return
            end
        else
            log.info("unkown command", task.type)
        end

        -- 任务等待
        if task.wait_timeout ~= nil and task.wait_timeout > 0 then
            local ret, info = iot.wait("executor_" .. Executor.id .. "_break", task.wait_timeout)
            if ret then
                -- 被中断
                log.info("被中断", info)
                break
            end
        end
    end

    -- 任务暂停
    if Executor.paused then
        -- log.info("pause")
        return
    end

    -- 任务结束
    Executor.job = "none"
    Executor.stoped = true

    log.info("execute finished")

    if Executor.on_finish ~= nil then
        Executor.on_finish()
    end
end

-- 恢复
function Executor:resume()
    Executor.paused = false
    iot.start(Executor.execute, Executor, Executor.current)
end

-- 启动
function Executor:start()
    iot.start(Executor.execute, Executor)
end

return Executor
