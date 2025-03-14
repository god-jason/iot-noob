local utils = {}


--- 删除目录及子文件
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
            io.rmdir(fn)
            log.info(tag, "remove dir", fn)
        else
            os.remove(fn)
            log.info(tag, "remove file", fn)
        end
    end
end

return utils
