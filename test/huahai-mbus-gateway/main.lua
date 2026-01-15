-- 主程序入口
PROJECT = "huahai-mbus-gateway"
VERSION = "1.0.5"

local tag = "main"

-- 引入系统适配层
require("iot")

log.info(tag, "last power reson", pm.lastReson())

-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

-- 日志等级改为info
log.setLevel(2)

-- 自动识别SIM2
-- mobile.simid(2, true)

-- 主进程
sys.taskInit(function()
    log.info(tag, "main task")

    sys.wait(1000) -- 等待USB初始化完成，否则日志丢失

    -- fskv.init() -- KV 数据库

    -- 加载所有程序文件
    require("autoload").walk("/luadb/")

    -- 启动网关
    require("gateway").boot()

    log.info(tag, "main task exit")
end)

sys.run()
