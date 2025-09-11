--- 主程序入口
--- @module main
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
PROJECT = "iot-noob"
VERSION = "1.0.0"
local tag = "main"

-- 引入sys，方便使用
_G.sys = require("sys")
_G.sysplus = require("sysplus")

log.info(tag, "last power reson", pm.lastReson())

-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

-- 日志等级改为info
log.setLevel(2)

-- 主进程
sys.taskInit(function()
    log.info(tag, "main task")

    fskv.init() -- KV 数据库

    -- 银尔达780系列 需要拉高 GPIO25，取消UART1输出屏蔽。。。
    -- gpio.setup(25, 1, gpio.PULLUP)

    -- W5500芯片供电
    -- gpio.setup(20, 1, gpio.PULLUP)

    -- 加载所有程序文件
    require("autoload")

    -- 加载设备
    require("devices").load()

    -- 打开连接
    require("links").load()

    -- TODO 定时器啥的

    log.info(tag, "main task exit")
end)

sys.run()
