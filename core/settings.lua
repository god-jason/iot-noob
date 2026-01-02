--- 对配置文件的封装，增加了时间戳，方便同步
-- @module database
local settings = {}
local tag = "setting"

local configs = require "configs"


-- 配置版本号
settings.versions = configs.load_default("versions", {})

-- 加载配置
function settings.load(name)
    settings[name] = configs.load_default(name, {})
end

-- 更新配置
function settings.update(name, content, version)
    settings[name] = content
    settings.versions[name] = version
    configs.save(name, content)
end

-- 保存配置
function settings.save(name)
    if  settings[name] ~= nil then
        configs.save(name,  settings[name])
    end
end

return settings
