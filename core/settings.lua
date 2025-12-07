--- 对配置文件的封装，增加了时间戳，方便同步
-- @module database
local settings = {}

local configs = require "configs"

-- 所有参数
local names = configs.load_default("settings", {})

settings.timesamps = {}

-- 加载配置
function settings.load(name)
    local config = configs.load_default(name, {})
    settings[name] = config.data or {}
    settings.timesamps[name] = config.timestamp or 0
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
    settings.save(name)
end

-- 保存配置
function settings.save(name)
    settings.timesamps[name] = os.time()
    configs.save(name, {
        data = settings[name],
        timestamp = os.time()
    })
end

return settings
