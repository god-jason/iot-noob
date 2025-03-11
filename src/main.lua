--- 主程序入口
--- @module main
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
PROJECT = "iot-noob"
VERSION = "1.0.0"

-- 开机检查
local tag = "MAIN"
log.info(tag, PROJECT, VERSION)
log.info(tag, "last power reson", pm.lastReson())

-- 引入sys，方便使用
_G.sys = require("sys")


-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

--检测内存使用
sys.timerLoopStart(function()
    collectgarbage()
end, 10 * 1000)


-- 电源指示灯

local sntp_sync_ok = false

local led = require("led")

-- 联网成功
sys.subscribe("IP_READY", function()
    log.info(tag, "IP_READY")
    
    led.on("net")

    -- 同步时钟（联通卡不会自动同步时钟，所以必须手动调整）
    if not sntp_sync_ok then
        socket.sntp()
        -- socket.sntp("ntp.aliyun.com") --自定义sntp服务器地址
        -- socket.sntp({"ntp.aliyun.com","ntp1.aliyun.com","ntp2.aliyun.com"}) --sntp自定义服务器地址
        -- socket.sntp(nil, socket.ETH0) --sntp自定义适配器序号
    end
    -- TODO 其他任务，比如连接云服务器等

end)

sys.subscribe("NTP_UPDATE", function()
    sntp_sync_ok = true
    -- 设置到RTC时钟芯片
    require("clock").write()
end)

-- 初始化外设
require("sd").init() -- SD卡
require("clock").init() -- 初始化时钟芯片
require("led").init() -- LED灯光
require("lan").init() -- 以太网
require("input").init() -- 输入
require("output").init() -- 输入
require("gnss").init() -- GPS定位
require("serial").init() -- 串口
require("cloud").init() -- 平台

-- gnss.init() --GPS定位

-- 加载连接器
require("link_serial")
-- require("link_tcp_client")

-- 加载协议库
require("protocol_modbus")
-- require("protocol_cjt188")
-- require("protocol_dlt645")
-- require("protocol_s7")

-- 启动网关系统程序
require("gateway").open()

sys.run()
