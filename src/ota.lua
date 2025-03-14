--- ota升级相关
--- @module "ota"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "ota"
local ota = {}

--- 下载回调
local function on_ota_download(result, prompt, head, body)
    log.info("result", result)
    if result then
        log.info(tag, "download success")
        log.info(tag, "reboot after 5s")

        -- TODO gateway.close() 可以发布全局消息以解耦

        -- 5秒后自动重启
        sys.timerStart(rtos.reboot, 5000)
        -- rtos.reboot() --重启
    else
        log.info(tag, "download failed")
    end
end

---下载文件(阻塞执行的)
---@param url string 下载链接
---@return boolean 成功与否
function ota.download(url)
    log.info(tag, "download", url)
    local code, headers, body = http.request("GET", url, {}, nil, {
        timeout = 30000,
        dst = "/update.bin"
    }).wait()
    log.info(tag, "download result", code, body)
    -- 阻塞执行的
    return code == 200
end

return ota
