PROJECT = "test"
VERSION = "1.0.0"

-- 引入sys，方便使用
_G.sys = require("sys")
_G.sysplus = require("sysplus")

-- 银尔达需要拉高
-- gpio.set(25, 1)
gpio.setup(25, 1, gpio.PULLUP)

local cron = require("cron")

-- 先同步时间
sys.subscribe("IP_READY", socket.sntp)
sys.subscribe("NTP_UPDATE", function()

    -- cron.start("* * * * * *", function()
    --     log.info("*")
    -- end)

    -- cron.start("*/5 * * * * *", function()
    --     log.info("*/5")
    -- end)

    -- cron.start("*/7 * * * * *", function()
    --     log.info("*/7")
    -- end)

    cron.start("11-17 * * * * *", function()
        log.info("11-17")
    end)

end)

sys.run()
