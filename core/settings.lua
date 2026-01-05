--- 对配置文件的封装，增加了版本号，方便同步
-- @module settings
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
    -- 保存配置
    settings[name] = content
    configs.save(name, content)

    -- 更新版本
    if version ~= nil then
        settings.versions[name] = version
    elseif settings.versions[name] ~= nil then
        settings.versions[name] = settings.versions[name] + 1 -- 自增版本号
    end
    configs.save("versions", settings.versions)

end

-- 保存配置
function settings.save(name)
    if  settings[name] ~= nil then
        configs.save(name,  settings[name])
    end
end

return settings
