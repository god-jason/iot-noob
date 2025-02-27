--- 主程序入口
-- @module main
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.01.20

PROJECT = "iot-noob"
VERSION = "1.0.0"
-- PRODUCT_KEY = ""

_G.sys = require("sys")
_G.sysplus =require("sysplus")


-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

pm.lastReson()

-- 检测内存使用
sys.timerLoopStart(function()
    collectgarbage()
end, 10 * 1000)


sys.run()