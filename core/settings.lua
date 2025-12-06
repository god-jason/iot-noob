local settings = {}

local configs = require "configs"

-- 所有参数
local names = {
    "network"
}

-- 加载配置
function settings.load(name)
    settings[name] = configs.load_default(name, {})
end

-- 加载所有配置
function settings.init()
    -- 逐一加载配置
    for i, name in ipairs(names) do
        settings.load(name)
    end
end

-- 更新配置
function settings.update(name, cfg)
    settings[name] = cfg
    configs.save(name, cfg)
end

function settings.save(name)
    configs.save(name, settings[name])
end

return settings
