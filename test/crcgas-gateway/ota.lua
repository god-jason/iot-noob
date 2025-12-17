local libfota2 = require "libfota2"

-- 产品Key, 请根据实际产品修改
PRODUCT_KEY = "jqeAzhScC7ofp918QkZPe2NiFWVBQJJl"

local master = require("master")

local function fota_end()
    log.info("fota", "切换回APN卡，继续工作")    
    -- 切换回APN卡，继续工作
    mobile.simid(0)
end

-- 固件升级结果回调函数
local function fota_cb(ret)
    log.info("fota", ret)
    if ret == 0 then
        log.info("升级包下载成功,重启模块")
        rtos.reboot()
    end

    -- 升级完成 30s 后切换回APN卡继续工作
    sys.timerStart(fota_end, 30000)
end

local function fota()
    log.info("fota", "开始升级流程")

    mobile.simid(1) -- 切换到SIM1进行升级

    -- 强制连接网关平台，下载配置和数据库
    --iot.start(master.task)

    -- 避免升级失败，无返回
    sys.timerStart(fota_end, 60000)
end

-- 定时自动升级, 每隔4小时自动检查一次
-- sys.timerLoopStart(libfota2.request, 4 * 3600000, fota_cb)
sys.timerLoopStart(fota, 4 * 3600000, fota_cb)
--sys.timerLoopStart(fota, 600000, fota_cb) -- 每10分钟检查一次

-- 启动60秒后进行第一次升级
sys.timerStart(fota, 10000)

-- 网络就绪后检查升级
sys.subscribe("IP_READY", function()
    libfota2.request(fota_cb)
end)
