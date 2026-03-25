--- 场景管理器
-- @module scenes
local scenes = {}
local actions = require("agent").actions()
local log = iot.logger("scenes")

local _scenes = {}

-- 注册到全局
_G.scenes = _scenes

local boot = require("boot")
local database = require("database")

local Scene = require("scene")

function scenes.remove(id)
    local s = _scenes[id]
    if s then
        return s:close()
    end
    return false, "找不到场景实例"
end

--- 创建场景
function scenes.create(scene)
    log.info("create", iot.json_encode(scene))

    -- 关掉上一个场景实例
    if _scenes[scene.id] then
        _scenes[scene.id]:close()
    end

    local s = Scene:new(scene)
    _scenes[scene.id] = s

    local ret, info = s:open()
    if not ret then
        return false, info
    end

    return true, s
end

--- 停用场景（包括禁用）
function scenes.stop(id)
    if _scenes[id] then
        _scenes[id]:close()
        return true
    end
    return false, "未启用的场景"
end

--- 执行场景
function scenes.execute(id)
    if _scenes[id] then
        _scenes[id]:execute()
        return true
    end
    return false, "未启用的场景"
end


-- 注册到命令，方便远程控制
function actions.scene_create(data)
    return scenes.create(data)
end
function actions.scene_stop(data)
    return scenes.stop(data.id)
end
function actions.scene_execute(data)
    return scenes.execute(data.id)
end

--- 加载场景
function scenes.open()
    local ss = database.find("scene")
    for i, s in ipairs(ss) do
        if not s.disabled then
            local ret, info = scenes.create(s)
            if not ret then
                log.error("scene:", s.id, " open error:", info)
            end
        end
    end

    return true
end

--- 关闭场景
function scenes.close()
    for i, s in pairs(_scenes) do
        s:close()
    end
    _scenes = {}
end

boot.register("scenes", scenes, "links", "master")

return scenes
