local scripts = {}

local log = iot.logger("scripts")
local boot = require("boot")
local database = require("database")

local _scripts = {}

-- 创建脚本
function scripts.create(name, script)
    if not script or #script == 0 then
        return false, "脚本是空"
    end

    -- 封装为闭包
    script = "return function(ctx)\n" .. script .. "\nend"

    local ret, info = load(script, "script_" .. name, "bt", _G)
    if not ret then
        -- log.info("compile script error", fn)
        return false, info
    end

    -- 返回闭包
    ret, info = iot.call(ret)
    if not ret then
        -- log.info("closure script error", fn)
        return ret, info
    end

    _scripts[name] = info
    return true
end

-- 执行脚本
function scripts.execute(name, ctx)
    local closure = _scripts[name]
    if not closure then
        log.error("execute script error", name, "not found")
        return false, "脚本不存在"
    end
    local ret, info = iot.call(closure, ctx)
    if not ret then
        log.error("execute script error", name, info)
    end
    return ret, info
end

function scripts.open()
    local ss = database.load("script")
    for k, s in pairs(ss) do
        local ret, info = scripts.create(k, s.content)
        if not ret then
            log.error("load script error", k, info)
        else
            log.info("load script", k)
        end
    end
    return true
end

-- 注册启动
boot.register("scripts", scripts)

return scripts
