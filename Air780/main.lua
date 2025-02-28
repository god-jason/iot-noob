--- 主程序入口
-- @module main
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.01.20

PROJECT = "iot-noob"
VERSION = "1.0.0"

_G.sys = require("sys")

local tag = "MAIN"

-- 开机检查
log.info(tag, PROJECT, VERSION)
log.info(tag, "last power reson", pm.lastReson())


-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

-- 检测内存使用
-- sys.timerLoopStart(function()
--     collectgarbage()
-- end, 10 * 1000)


local sntp_sync_ok = false

-- 网关成功
sys.subscribe("IP_READY", function()
    log.info(tag, "IP_READY")

    -- 同步时钟（联通卡不会自动同步时钟，所以必须手动调整）
    if not sntp_sync_ok then
        socket.sntp()
        --socket.sntp("ntp.aliyun.com") --自定义sntp服务器地址
        --socket.sntp({"ntp.aliyun.com","ntp1.aliyun.com","ntp2.aliyun.com"}) --sntp自定义服务器地址
        --socket.sntp(nil, socket.ETH0) --sntp自定义适配器序号    
    end

    -- TODO

end)

sys.subscribe("NTP_UPDATE", function()
    sntp_sync_ok = true
    -- 设置到RTC时钟芯片    
    rtc_write()
end)

-- TODO 初始化外设
led_init() -- LED灯光
lan_init() -- 以太网
io_init() -- 输入输出

-- gnss_init()


-- TODO 启动网关系统程序



sys.run()
