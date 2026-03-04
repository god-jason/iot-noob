local log = iot.logger("boot")

local boot = {}

local modules = {}
local boots = {}

-- 注册模块
function boot.register(name, mod)
    if type(mod) ~= "table" then
        log.error("register", name, "is not a module")
    end
    modules[name] = {
        open = mod.open,
        close = mod.close,
        deps = mod.deps or {},
        opened = false,
        visiting = false
    }
end

-- 启动模块
function boot.open(name)
    local mod = modules[name]
    if not mod then
        return false, "cannot find module" .. name
    end

    if mod.opened then
        return true
    end

    if mod.visiting then
        return false, "circular dependency"
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

    log.info("open module", name)
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

-- 关闭模块
function boot.close(name)
    local mod = modules[name]
    if not mod then
        return
    end

    if not mod.close then
        return
    end

    log.info("close module", name)
    local ret, res, info = pcall(mod.close)
    if not ret then
        log.error(res)
    end
    if res == false then
        log.error(info)
    end

    mod.opened = false
end

-- 启动
function boot.startup()
    for name, mod in pairs(modules) do
        local ret, info = boot.open(name)
        if not ret then
            log.error(info)
            -- 非发布时，关闭程序
            if not RELEASE then
                boot.shutdown()
                error(info)
            end

            -- return 不能返回，避免平台模块不正常
        end
    end
end

-- 停止
function boot.shutdown()
    -- 逆序关闭
    for i = #boots, 1, -1 do
        boot.close(boots[i])
    end
    boots = {}
end

return boot
