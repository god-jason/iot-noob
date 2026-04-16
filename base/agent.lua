--- 远程控制器
-- @module agent
local agent = {}

local log = iot.logger("agent")

local configs = require("configs")
local settings = require("settings")
local database = require("database")
local master = require("master")

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

    return iot.xcall(cmd, data or {})
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

-- 基础配置操作
function actions.config(data)
    local op = data.operator or data.op
    local cfg = data.config or data.cfg
    if op == "read" then
        return configs.load(cfg)
    elseif op == "write" then
        return configs.save(cfg, data.content or data.data)
    elseif op == "delete" then
        return configs.delete(cfg)
    else
        return false, "未支持的配置操作"
    end
end

-- 通用配置操作（带版本号）
function actions.settings(data)
    local op = data.operator or data.op
    local cfg = data.name or data.config or data.setting or data.cfg

    if op == "read" or op == "load" then
        return settings.load(cfg)
    elseif op == "write" or op == "update" then
        return settings.update(cfg, data.content or data.data, data.version)
    elseif op == "reset" then
        return configs.reset(cfg)
    else
        return false, "未支持的配置操作"
    end
end

-- 数据库操作
function actions.database(data)
    local op = data.operator or data.op
    local db = data.database or data.db

    if op == "clear" then
        return database.clear(db)
    elseif op == "sync" then -- 同步数据库
        database.clear(db)
        return database.insertArray(db, data.content or data.data)
    elseif op == "delete" then
        return database.delete(db, data.id)
    elseif op == "update" then
        return database.update(db, data.id, data.content or data.data)
    elseif op == "insert" then
        return database.insert(db, data.id, data.content or data.data)
    elseif op == "insertMany" then
        return database.insertMany(db, data.content or data.data)
    elseif op == "insertArray" then
        return database.insertArray(db, data.content or data.data)
    elseif op == "load" then
        return true, database.load(db)
    elseif op == "find" then
        return true, database.find(db, unpack(data.query or {}))
    else
        return false, "未支持的数据库操作"
    end
end

-- 轮询全部设备
function actions.polling(data)
    if not links then
        return false, "没有连接模块"
    end

    -- 如果未指定连接，则轮询全部连接
    local lnks = links
    if data.link_id and #data.link_id > 0 then
        lnks = {links[data.link_id]}
    end

    iot.start(function()
        for k, link in pairs(lnks) do
            if link.protocol_instance and link.protocol_instance.polling_all then
                link.protocol_instance:polling_all()
            end
        end    
    end)
    return true
end

return agent
