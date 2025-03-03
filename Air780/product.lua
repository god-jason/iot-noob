--[[
{
}
]]

local demo_poller = {
    code = 3,
    addr = 1002,
    size = 54,
    format = ">F20",
    points = { "uan", "ubn", "ucn", "udn", "_", "_", "_", "_", "_", "_", "_", "_", "f" }
}


--- 加载配置
function load(id, config)
    local path = "/product/" .. id .. "/" .. config .. ".json"
    if SD.enable then
        path = "/sd" .. path
    end

    if not io.exists(path) then
        download(id, config)
    end

    io.open(path, "r")
end

-- 下载配置
function download(id, config)
    local dir = "/product/" .. id
    if SD.enable then
        dir = "/sd" .. dir
    end
    if not io.exists(dir) then
        io.mkdir(dir)
    end
    local path = dir .. "/" .. config .. ".json"
    os.remove(path) --先删除

    local url = "http://iot.busycloud.cn/noob/product/" .. id .. "/" .. config .. ".json"

    -- 下载文件
    local code, headers, body = http.request("GET", url, {}, "", { dst = path }).wait()

    -- 
end
