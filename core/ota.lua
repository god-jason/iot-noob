--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- ota升级相关
-- @module OTA升级
local ota = {}

local tag = "ota"

---下载文件(阻塞执行的)
-- @param url string 下载链接
-- @return boolean 成功与否
function ota.download(url)
    log.info(tag, "download", url)
    sys.taskInit(function()
        local code, headers, body = http.request("GET", url, {}, nil, {
            -- timeout = 30000,
            fota = true -- 780EPM改用fota模块
            -- dst = "/update.bin"
        }).wait()
        log.info(tag, "download result", code, headers, body)

        if code == 200 then
            -- TODO gateway.close() 可以发布全局消息以解耦

            -- 5秒后自动重启
            sys.timerStart(rtos.reboot, 15000)
            log.info(tag, "reboot after 15s")
        end
    end)
end

return ota
