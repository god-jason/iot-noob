--- 高度接口
--- @module "debug"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.12
local tag = "debug"
local debug = {}

local function ls_dir(path)
    local ret, data = io.lsdir(path, 50, 0)
    if not ret then return end

    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            ls_dir(fn.."/")
        else
            log.info(tag, fn, e.size)
        end
    end
end



local function remove_all(path)
    local ret, data = io.lsdir(path, 50, 0)
    if not ret then return end

    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            remove_all(fn.."/")
            io.rmdir(fn)
            log.info(tag, "remove", fn)
        else
            os.remove(fn)
            log.info(tag, "remove", fn)
        end
    end
end

function debug.walk()
    ls_dir("/")
end

function debug.clear()
    -- io.rmdir("/")
    remove_all("/")
end


return debug
