--- 对配置文件的封装，增加了版本号，方便同步
-- @module settings
local settings = {}

local log = iot.logger("settings")

local configs = require("configs")
local boot = require("boot")
local yaml = require("yaml")

-- 版本号
settings.versions = configs.load_default("versions", {})

local defaults = {}

--- 注册默认配置
function settings.register(name, default)
    -- table.insert(options.names, name)

    -- 默认版本为0
    if not settings.versions[name] then
        settings.versions[name] = 0
    end

    defaults[name] = default
end

--- 加载配置
function settings.load(name)
    local cfg = configs.load_default(name, defaults[name] or {})
    -- log.info("load", name, yaml.encode(cfg))
    -- log.info("load", name, iot.json_encode(cfg))
    settings[name] = cfg
    return true, cfg
end

--- 更新配置
function settings.update(name, content, version)
    -- 保存配置
    settings[name] = content
    configs.save(name, content)

    -- 通知组件
    iot.emit("SETTING", name)

    -- 更新版本
    if version ~= nil then
        settings.versions[name] = version
    elseif settings.versions[name] ~= nil then
        settings.versions[name] = settings.versions[name] + 1 -- 自增版本号
    end

    return configs.save("versions", settings.versions)
end

--- 保存配置
function settings.save(name)
    if settings[name] ~= nil then
        return configs.save(name, settings[name])
    end
    return false, "缺少名称"
end

--- 清空配置
-- @param name
function settings.reset(name)
    if name then
        configs.delete(name)
    else
        for i, n in pairs(settings.versions) do
            configs.delete(i)
        end
    end
    return true
end

--- 加载配置
function settings.open()
    log.info("load", iot.json_encode(settings.versions.names))

    -- for i, name in ipairs(options.names) do
    for name, ver in pairs(settings.versions) do
        settings.load(name)
    end
end

--- 关闭配置
function settings.close()
    -- 保存
end

boot.register("settings", settings)

return settings
