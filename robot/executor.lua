local log = iot.logger("executor")

local vm = require("vm")
local utils = require("utils")

-- 自增ID
local inc = utils.increment()

--- 执行器
-- @module Executor
local Executor = {}
Executor.__index = Executor

--- 创建实例
function Executor:new(opts)
    opts = opts or {}
    return setmetatable({
        id = inc(),
        job = opts.job or "-",
        tasks = opts.tasks or {},
        on_finish = opts.on_finish,
        on_error = opts.on_error,
        current = 1,
        context = {},
        conditions = {}
    }, Executor)
end

--- 复制实例（无用）
function Executor:clone()
    return setmetatable({
        id = inc(),
        job = self.job,
        tasks = self.tasks,
        on_finish = self.on_finish,
        on_error = self.on_error,
        current = 1,
        context = {},
        conditions = {}
    }, Executor)
end

--- 暂停
function Executor:pause()
    self.paused = true
    iot.emit("executor_" .. self.id .. "_break")
end

--- 停止
function Executor:stop()
    self.stoped = true
    iot.emit("executor_" .. self.id .. "_break")
end

--- 执行（内部用）
function Executor:execute(cursor)
    cursor = cursor or 1 -- 默认从头开始
    log.info("execute", cursor, iot.json_encode(self.tasks))

    -- 从起始任务执行
    self.current = cursor

    while self.current <= #self.tasks and not self.paused and not self.stoped do
        ::continue::

        local task = self.tasks[self.current]
        log.info("task", self.current, iot.json_encode(task))

        -- 条件指令
        local cond = self.conditions[self.current]
        if type(cond) == "function" then
            local ret, info = pcall(cond)
            if not ret then
                log.error(info)
                -- 上报错误
                if self.on_error then
                    self.on_error(info)
                end
                return
            end

            -- 条件不满足，跳过当前指令
            if not info then
                self.current = self.current + 1
                goto continue
            end
        end

        -- 执行任务
        local fn = vm[task.type]
        if type(fn) == "function" then
            -- fn(task)
            local ret, info, wait = pcall(fn, task, self.context, self)
            if not ret then
                log.error(info)
                -- 上报错误
                if self.on_error then
                    self.on_error(info)
                end
                return
            end

            -- 任务等待
            if info then
                ret = iot.wait("executor_" .. self.id .. "_break", wait)
                if ret then
                    -- 被中断
                    log.info("被中断")
                    break
                end
            end
        else
            -- 不会发生
            log.info("未知类型", task.type)
        end

        -- 下一条
        self.current = self.current + 1
    end

    -- 任务暂停
    if self.paused then
        -- log.info("pause")
        return
    end

    -- 任务结束
    self.job = "none"
    self.stoped = true

    log.info("execute finished")

    if self.on_finish ~= nil then
        self.on_finish()
    end
end

--- 恢复
function Executor:resume()
    self.paused = false
    iot.start(Executor.execute, self, self.current)
end

--- 启动
function Executor:start()

    -- 编译条件
    for i, task in ipairs(self.tasks) do

        if type(task.condition) == "string" then
            local script = "return " .. task.condition
            -- 编译
            local ret, info = load(script, "vm_condition", "t", {
                components = _G.components,
                devices = _G.devices,
                context = self.context
            })
            if not ret then
                return false, info
            end

            -- 放到这里会污染指令，导致无法序列化
            -- task.condition = ret
            self.conditions[i] = ret
        end

        -- 预查指令
        local fn = vm[task.type]
        if type(fn) ~= "function" then
            return false, "找不到指令" .. task.type
        end
    end

    iot.start(Executor.execute, self)

    return true
end

return Executor
