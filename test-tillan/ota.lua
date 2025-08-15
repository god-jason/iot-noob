libfota2 = require "libfota2"

local function fota_cb(ret)
    log.info("fota", ret)
    if ret == 0 then
        log.info("升级包下载成功,重启模块")
        rtos.reboot()
    end
end

-- 手动检查升级
libfota2.request(fota_cb)

-- 定时自动升级, 每隔4小时自动检查一次
sys.timerLoopStart(libfota2.request, 4 * 3600000, fota_cb)
