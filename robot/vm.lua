local log = iot.logger("vm")

local instructions = {}

local utils = require("utils")

-- 自增ID
local inc = utils.increment()

-- 定义实例
local VM = {}
VM.__index = VM

-- 注册指令
function VM.register(name, handler)
    instructions[name] = handler
end

-- 创建实例
function VM:new(opts)
    opts = opts or {}
    return setmetatable({
        id = inc(),
        job = opts.job or "-",
        tasks = opts.tasks or {},
        on_finish = opts.on_finish,
        on_error = opts.on_error,
        current = 1,
        context = {}
    }, VM)
end

-- 复制实例
function VM:clone()
    return setmetatable({
        id = inc(),
        job = self.job,
        tasks = self.tasks,
        on_finish = self.on_finish,
        on_error = self.on_error,
        current = 1,
        context = {}
    }, VM)
end

-- 暂停
function VM:pause()
    self.paused = true
    iot.emit("runtime_" .. self.id .. "_break")
end

-- 停止
function VM:stop()
    iot.emit("runtime_" .. self.id .. "_break")
end

-- 执行（内部用）
function VM:execute(cursor)
    cursor = cursor or 1 -- 默认从头开始
    log.info("execute", cursor, json.encode(self.tasks))

    -- 从起始任务执行
    for i = cursor, #self.tasks, 1 do
        local task = self.tasks[i]
        log.info("task", i, iot.json_encode(task))
        self.current = i

        local fn = instructions[task.type]
        if type(fn) == "function" then
            -- fn(task)
            local ret, info = pcall(fn, self.context, task)
            if not ret then
                log.error(info)
                -- 上报错误
                if not self.on_error then
                    self.on_error(info)
                end

                -- TODO 设备状态
                return
            end
        else
            log.info("unkown command", task.type)
        end

        -- 任务等待
        if task.wait_timeout ~= nil and task.wait_timeout > 0 then
            local ret, info = iot.wait("runtime_" .. self.id .. "_break", task.wait_timeout)
            if ret then
                -- 被中断
                log.info("被中断", info)
                break
            end
        end
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

-- 恢复
function VM:resume()
    self.paused = false
    iot.start(VM.execute, self, self.current)
end

-- 启动
function VM:start()
    iot.start(VM.execute, self)
end

return VM
