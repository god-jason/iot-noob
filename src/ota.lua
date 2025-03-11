local tag = "ota"
local ota = {}

local function on_ota_download(result, prompt, head, body)
    log.info("result", result)
    if result then
        log.info("ota download ok")
        log.info("reboot after 5s")

        -- TODO gateway.close()

        -- 5秒后自动重启
        sys.timerStart(rtos.reboot, 5000)
        -- rtos.reboot() --重启
    else
        log.info("ota download failed")
    end
end

function ota.download(url)
    http.request("GET", url, nil, nil, nil, 30000, on_ota_download, "/update.bin")
end

return ota