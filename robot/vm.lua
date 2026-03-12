--- 虚拟机（由Planner生成，Executor最终执行）
-- @module vm
local vm = {}

--- 等待指令
function vm.wait(task)
    return true, task.timeout or task.wait
end

--- 跳转指令
function vm.jump(task, ctx, executor)
    if task.label then
        -- 名称跳转
        for i, t in ipairs(executor.tasks) do
            if t.name == task.label then
                executor.current = i - 1
                return
            end
        end
        -- 找不到任务
        error("cannot found task named:" .. task.label)
    elseif task.index then
        if task.index < 1 or task.index > #executor.tasks then
            error("jump overflow " .. task.index)
        end
        -- 执行器中会自增，需要抵消
        executor.current = task.index - 1
    end
end

--- 回滚指令，向上推进数量
function vm.rollback(task, ctx, executor)
    -- 默认1条
    local count = task.count or 1

    -- 执行器中会自增，需要抵消
    executor.current = executor.current - count - 1

    -- 避免向上溢出
    if executor.current < 0 then
        error("rollback to many tasks" .. count)
    end
end

--- 跳过指令
function vm.skip(task, ctx, executor)
    -- 默认1条
    local count = task.count or 1
    executor.current = executor.current + count
end

return vm
