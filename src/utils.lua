--- 工具库
--- @module "utils"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.14
local tag = "utils"
local utils = {}

--- 删除目录,以及下面所有的子目录和文件
---@param path string 目录
function utils.remove_all(path)
    local ret, data = io.lsdir(path, 50, 0)
    if not ret then
        return
    end

    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            utils.remove_all(fn .. "/")
            log.info(tag, "remove dir", fn)
            io.rmdir(fn)
        else
            os.remove(fn)
            log.info(tag, "remove file", fn)
        end
    end

    -- 继续遍历
    if #data == 50 then
        utils.remove_all(path)
    end
end

function utils.walk(path)
    local ret, data = io.lsdir(path, 50, 0)
    if not ret then
        return
    end

    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            log.info(tag, "walk", fn)
            utils.walk(fn .. "/")
        else
            log.info(tag, "walk", fn, e.size)
        end
    end

    -- 继续遍历
    if #data == 50 then
        utils.walk(path)
    end
end

return utils
