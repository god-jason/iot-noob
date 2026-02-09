local libfota2 = require "libfota2"

-- 产品Key, 请根据实际产品修改
PRODUCT_KEY = "BDOh8GxyUtXhEEOO7obVjx6ruOylAn6k"

local function fota_cb(ret)
    log.info("fota", ret)
    if ret == 0 then
        log.info("升级包下载成功,重启模块")
        rtos.reboot()
    end
end

-- 定时自动升级, 每隔4小时自动检查一次
-- sys.timerLoopStart(libfota2.request, 4 * 3600000, fota_cb)
sys.timerLoopStart(libfota2.request, 4 * 3600000, fota_cb)

-- 网络就绪后检查升级
sys.subscribe("IP_READY", function()
    libfota2.request(fota_cb)
end)
