PROJECT = "zetian"
VERSION = "1.0.0"
-- 合宙IoT平台产品Key, OTA升级用
PRODUCT_KEY = "6dynGZCXPmiL1x5NBlRkSRhPAs3eG4ao"


-- 发行模式
DEBUG = false

if not DEBUG then
    -- 避免VM重启
    COROUTINE_ERROR_ROLL_BACK = false
    COROUTINE_ERROR_RESTART = false
end

-- 引入系统适配层
require("iot")

log.info("上次关机原因", pm.lastReson())

-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

-- 日志等级改为info
-- log.setLevel(2)

-- 自动识别SIM2
mobile.simid(2, true)


-- 关闭银尔达看门狗（watch_dog组件无用）
local air153C_wtd = require 'air153C_wtd'
air153C_wtd.init(28)
air153C_wtd.close_watch_dog(28)

-- 主进程
sys.taskInit(function()
    log.info("task")

    -- 等待USB初始化完成，否则日志丢失
    sys.wait(200) -- sys.wait(1000)

    -- fskv.init() -- KV 数据库

    -- 自动加载所有程序文件
    require("autoload").walk("/luadb/")

    -- 自动启动模块
    require("boot").startup()

    -- 打印内存占用
    if DEBUG then
        while true do
            sys.wait(5000)
            log.info("内存", rtos.meminfo())
        end
    end

    log.info("exit")
end)

sys.run()
