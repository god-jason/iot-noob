--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- 主程序入口
PROJECT = "iot-noob"
VERSION = "1.0.0"
local tag = "main"

-- 引入系统适配层
require("adapter")

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

    sys.wait(1000) -- 等待USB初始化完成，否则日志丢失

    --fskv.init() -- KV 数据库

    -- 加载所有程序文件
    require("autoload").walk("/luadb/")

    -- 启动网关
    require("gateway").boot()

    log.info(tag, "main task exit")
end)

sys.run()
