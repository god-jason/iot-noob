--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- 主程序入口

PROJECT = "iot-noob"
VERSION = "1.0.0"
local tag = "main"

-- 引入sys，方便使用
_G.sys = require("sys")

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

    -- 加载所有程序文件
    require("autoload").walk("/luadb/")

    -- 加载设备
    require("gateway").load_links()

    -- TODO 定时器啥的

    log.info(tag, "main task exit")
end)

sys.run()
