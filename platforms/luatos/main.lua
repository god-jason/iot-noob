-- 主程序入口
PROJECT = "iot-os"
VERSION = "1.0.0"

-- 引入系统适配层
require("iot")

log.info("开始原因", pm.lastReson())

-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

-- 日志等级改为info
--log.setLevel(2)

-- 自动识别SIM2
mobile.simid(2, true)

-- 主进程
sys.taskInit(function()
    log.info("task")

    if not RELEASE then
        --sys.wait(1000) -- 等待USB初始化完成，否则日志丢失    
    end    

    -- fskv.init() -- KV 数据库

    -- 自动加载所有程序文件
    require("autoload").walk("/luadb/")

    -- 自动启动模块
    require("boot").startup()

    while not RELEASE do
        sys.wait(5000)
        log.info("内存", rtos.meminfo())
    end
    
    log.info("exit")
end)

sys.run()
