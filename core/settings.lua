--- 对配置文件的封装，增加了时间戳，方便同步
-- @module database
local settings = {}
local tag = "setting"

-- local timestamp_name = "settings"

local configs = require "configs"

-- 所有参数
--local names = configs.load_default("settings", {})

settings.timestamps = configs.load_default("timestamps", {})

-- 加载配置
function settings.load(name)
    settings[name] = configs.load_default(name, {})
end

-- 更新配置
function settings.update(name, cfg)
    settings.timestamps[name] = os.time()
    settings[name] = cfg
    configs.save(name, cfg)
end

-- 保存配置
function settings.save(name)
    if  settings[name] ~= nil then
        configs.save(name,  settings[name])
    end
end

return settings
