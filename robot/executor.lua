--- 执行器
-- @module Executor
local Executor = {}
Executor.__index = Executor

local log = iot.logger("executor")
local vm = require("vm")
local utils = require("utils")
local yaml = require("yaml")

-- 自增ID
local inc = utils.increment()

--- 创建实例
function Executor:new(opts)
    opts = opts or {}
    return setmetatable({
        id = inc(),
        job = opts.job or "-",
        tasks = opts.tasks or {},
        on_finish = opts.on_finish,
        on_error = opts.on_error,
        -- on_task_start = opts.on_task_start,
        current = 1,
        context = {}
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
        context = {}
    }, Executor)
end

--- 暂停
function Executor:pause()
    if self.paused or self.stoped or self.current >= #self.tasks then
        return
    end

    self.paused = true
    self.pause_time = os.time()
    self:interrupt()
end

--- 停止
function Executor:stop()
    if self.stoped or self.current >= #self.tasks then
        return
    end

    self.stoped = true
    self:interrupt()
end

--- 中断当前任务等待
function Executor:interrupt()
    iot.emit("executor_" .. self.id .. "_break")
end

function Executor:wait(timeout)
    return iot.wait("executor_" .. self.id .. "_break", timeout)
end

--- 执行（内部用）
function Executor:execute(cursor)
    cursor = cursor or 1 -- 默认从头开始
    log.info(self.job, "execute", cursor, iot.json_encode(self.tasks))

    -- 执行恢复指令
    if cursor > 1 and cursor <= #self.tasks then
        local task = self.tasks[cursor]
        if vm.resume then
            iot.call(vm.resume, task, self.context, self)
        end
    end

    -- 从起始任务执行
    self.current = cursor

    while self.current <= #self.tasks and not self.paused and not self.stoped do
        ::continue::

        local task = self.tasks[self.current]
        log.info(self.job, "task", self.current, iot.json_encode(task))

        -- 记录起始时间
        local start_time = os.date("%X") -- 记录起始 时分秒

        -- 条件指令
        local cond = task._condition or task.condition
        if type(cond) == "function" then
            local ret, info = iot.call(cond, self.context, self)
            if not ret then
                -- 记录错误
                task.error = info
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
            local ret, wait = iot.xcall(fn, task, self.context, self)
            if ret == false then
                -- 记录错误
                task.error = wait
                -- 上报错误
                if self.on_error then
                    self.on_error(wait)
                end
                return
            end

            -- 任务等待
            if ret == true and wait and wait > 0 then
                ret = self:wait(wait)
                -- ret = iot.wait("executor_" .. self.id .. "_break", wait)
                if ret then
                    -- 被中断
                    log.info(self.job, "break")
                    -- break
                    -- TODO 恢复时，要计算等待时间
                end
            end
        else
            -- 不会发生
            log.info(self.job, "未知类型", task.type)
        end

        local end_time = os.date("%X") -- 记录结时间
        task.executed = start_time .. " - " .. end_time

        -- 下一条
        self.current = self.current + 1
    end

    -- 任务暂停
    if self.paused then
        iot.call(vm.pause, {}, self.context, self)
        return
    end

    -- 执行停止指令，用于结束动作
    -- vm.stop({}, self.context)
    if vm.stop then
        iot.call(vm.stop, {}, self.context, self)
    end

    -- 任务结束
    self.stoped = true
    self.end_time = os.date("%X") -- 记录当前 时分秒

    -- 异常结束
    -- if self.current < #self.tasks then
    --     if self.on_error then
    --         self.on_error("被中止")
    --     end
    -- end

    -- 正常结束
    if self.current >= #self.tasks then
        if self.on_finish then
            iot.call(self.on_finish, self.context)
        end
    end

    local text = yaml.encode(self)
    log.info(self.job, "execute finished", text)
    -- iot.emit("log", "### 执行器结果 " .. text)

    -- 置空当前任务
    self.job = "-"
end

--- 恢复
function Executor:resume()
    if not self.paused or self.current > #self.tasks then
        return false, "不是暂停的任务"
    end
    self.paused = false
    iot.start(Executor.execute, self, self.current)
    return true
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
                robot = _G.robot,
                context = self.context
            })
            if not ret then
                return false, info
            end

            -- 保留原表达式
            task._condition = ret
        end

        -- 预查指令
        local fn = vm[task.type]
        if type(fn) ~= "function" then
            return false, "找不到指令" .. task.type
        end
    end

    self.start_time = os.date("%X") -- 记录当前 时分秒

    -- 统一延迟200ms执行，避免上次任务未完全结束
    iot.setTimeout(iot.start, 200, Executor.execute, self)

    return true
end

return Executor
