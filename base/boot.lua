--- 启动器
-- @module boot
local boot = {}

local log = iot.logger("boot")

local modules = {}
local boots = {}

--- 注册模块
-- @param name string
-- @param mod table
function boot.register(name, mod)

    if type(mod) ~= "table" then
        log.error(name, "不是模块")
        return
    end

    modules[name] = {
        open = mod.open,
        close = mod.close,
        deps = mod.deps or {},
        opened = false,
        visiting = false
    }
end

--- 启动模块
-- @param name string
-- @return boolean 成功与否
-- @return string 错误信息
function boot.open(name)
    local mod = modules[name]
    if not mod then
        return false, "找不到模块" .. name
    end

    if mod.opened then
        return true
    end

    if mod.visiting then
        return false, "循环依赖"
    end
    mod.visiting = true

    -- 启动依赖项
    for i, v in ipairs(mod.deps) do
        local ret, info = boot.open(v)
        if not ret then
            mod.visiting = false
            return false, info
        end
    end

    mod.visiting = false

    log.info("open", name)
    local ret, res, info = pcall(mod.open)
    if not ret then
        return false, res
    end
    if res == false then
        return false, info
    end

    -- 记录启动顺序
    table.insert(boots, name)

    -- 避免重入
    mod.opened = true
    return true
end

--- 关闭模块
-- @param name string
function boot.close(name)
    local mod = modules[name]
    if not mod then
        return
    end

    if not mod.close then
        return
    end

    log.info("close", name)
    local ret, res, info = pcall(mod.close)
    if not ret then
        log.error(res)
    end
    if res == false then
        log.error(info)
    end

    mod.opened = false
end

--- 启动
-- @return boolean 成功与否
-- @return string 错误信息
function boot.startup()
    for name, mod in pairs(modules) do
        local ret, info = boot.open(name)
        if not ret then
            log.error(info)

            -- 非发布时，关闭程序，抛出异常
            if not RELEASE then
                boot.shutdown()
                error(info)
            end

            -- 发布时，要启动平台模块，至少实现重置和远程升级
        end
    end
end

--- 停止
function boot.shutdown()
    -- 逆序关闭
    for i = #boots, 1, -1 do
        boot.close(boots[i])
    end
    boots = {}
end

return boot
