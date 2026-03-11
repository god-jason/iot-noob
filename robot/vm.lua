local vm = {}

-- 等待指令
vm['wait'] = function(task)
    return task.timeout
end

-- 重复指令，向上推进数量
vm['rollback'] = function(task, ctx, executor)
    -- 默认1条
    local count = task.count or 1

    -- 执行器中会自增，需要抵消
    executor.current = executor.current - count - 1

    -- 避免向上溢出
    if executor.current < 0 then
        executor.current = 0
    end
end

-- 跳转指令
vm['goto'] = function(task, ctx, executor)
    -- 执行器中会自增，需要抵消
    executor.current = task.index - 1

    -- 避免向上溢出
    if executor.current < 0 then
        executor.current = 0
    end
end

-- 跳过指令
vm['skip'] = function(task, ctx, executor)
    -- 默认1条
    local count = task.count or 1
    executor.current = executor.current + count
end

return vm
