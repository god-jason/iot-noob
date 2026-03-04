--- 对配置文件的封装，增加了版本号，方便同步
-- @module settings
local settings = {}

local log = iot.logger("setting")
local configs = require("configs")
local boot = require("boot")

local options = {
    names = {},
    versions = {}
}

local defaults = {}

-- 注册默认配置
function settings.register(name, default)
    table.insert(options.names, name)
    defaults[name] = default
end

-- 加载配置
function settings.load(name)
    settings[name] = configs.load_default(name, defaults[name] or {})
end

-- 更新配置
function settings.update(name, content, version)
    -- 保存配置
    settings[name] = content
    configs.save(name, content)

    -- 更新版本
    if version ~= nil then
        options.versions[name] = version
    elseif options.versions[name] ~= nil then
        options.versions[name] = options.versions[name] + 1 -- 自增版本号
    end
    configs.save("settings", options)
end

-- 保存配置
function settings.save(name)
    if settings[name] ~= nil then
        configs.save(name, settings[name])
    end
end

-- 清空配置
function settings.reset(name)
    if name then
        configs.delete(name)
    else
        for i, name in ipairs(options.names) do
            configs.delete(name)
        end
    end
end

-- 加载配置
function settings.open()
    -- 加载配置
    options = configs.load_default("settings", options)

    for i, name in ipairs(options.names) do
        settings.load(name)
    end
end

-- 关闭配置
function settings.close()
    -- 保存
end

boot.register("settings", settings)

return settings
