--- 模块功能：配置文件
-- @module config
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30

module(..., package.seeall)

local MOD = "CONFIG"

require "fs"

-- 配置文件根目录
local root = "/noob/"
if not fs.exists(root) then
    fs.makeDir(root) -- 自动创建
end

-- 加载配置文件
function load(cfg)
    local fn = root .. cfg .. ".json"
    if not fs.exists(cfg) then return false end
    local data = fs.read(fn)
    if #data > 0 then return true, json.decode(data) end
    return false
end

-- 写入配置文件
function store(cfg, data)
    local fn = root .. cfg .. ".json"
    return fs.write(fn, json.encode(data))
end


-- 删除配置文件
function remove(cfg)
    local fn = root .. cfg .. ".json"
    return fs.remove(fn)
end
