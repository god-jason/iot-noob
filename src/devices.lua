local tag     = "device"
local devices = {}

function devices.load_by_link(id)
    -- 找文件
    local path = "/devices/" .. id .. ".json"
    if SD.enable then
        path = "/sd" .. path
    end

    -- 找不到，则下载
    if not io.exists(path) then return false end

    local size = io.fileSize(path)
    if size > 20000 then
        log.info(tag, "too large", path, size)
        return false
    end

    local data = io.readFile(path)
    local obj, ret, err = json.decode(data)
    if ret == 1 then
        return true, obj
    else
        log.info(tag, "parse failed", path, err)
        return false, err
    end
end

return devices
