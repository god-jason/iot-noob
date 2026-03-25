--- 远程控制器
-- @module agent
local agent = {}

local log = iot.logger("agent")

local actions = {}

--- 所有命令
-- @return table
function agent.actions()
    return actions
end

--- 注册命令
-- @param name string|table 命令
-- @param fn function 回凋
function agent.register(name, fn)
    if type(name) == "string" and type(fn) == "function" then
        actions[name] = fn
    end

    -- 批量注册
    if type(name) == "table" then
        for k, v in pairs(name) do
            if type(v) == "function" then
                actions[k] = v
            end
        end
    end
end

--- 执行命令
-- @param name string 命令
-- @param data table 参数
-- @return boolean 成功与否
-- @return string 错误信息 或 结果
function agent.execute(name, data)
    local cmd = actions[name]
    if type(cmd) ~= "function" then
        return false, "找不到命令：" .. name
    end

    return iot.xcall(cmd, data)
end

agent.watching = false
local watcher = 0

-- 观察
function actions.watch(data)
    log.info("查看")
    iot.emit("report", true)

    watcher = watcher + 1

    agent.watching = true

    local w = watcher

    local tm = (data.value or 1) * 60000
    iot.setTimeout(function()
        -- 只在最后一个定时结束时，结束监听
        if w == watcher then
            agent.watching = false
        end
    end, tm)
    return true
end

-- 重启设备
function actions.reboot()
    iot.reboot()
    return true
end

-- 清除数据
function actions.reset()
    -- 删除所有文件，恢复出厂设置
    iot.walk("/", function(fn)
        log.info("remove", fn)
        os.remove(fn)
    end)
    iot.reboot()
    return true
end

-- 固件升级
function actions.upgrade(data)
    if data.url and #data.url > 0 then
        iot.upgrade(data.url)
    else
        -- 触发合宙的OTA升级，限制较多，KEY要匹配，模组要在IoT平台名下
        iot.emit("FOTA", "固件升级")
    end
    return true
end

return agent
