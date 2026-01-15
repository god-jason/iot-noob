local tag = "switch"

local gateway = require("gateway")
local settings = require("settings")

-- 加载配置
settings.load("switch")

-- 透传时间 2s
local pipe_timeout = 5000

iot.start(function()
    -- 等待网关启动完成
    iot.wait("GATEWAY_READY")

    log.info(tag, "start switch")

    local uart1 = gateway.get_link_instanse("RS485-1")
    local uart2 = gateway.get_link_instanse("RS485-2")

    while true do
        local tm1 = (settings.switch.uart1 or 10) * 1000
        local tm2 = (settings.switch.uart2 or 10) * 1000

        iot.sleep(tm1)
        uart1:pipe(uart2)
        log.info(tag, "switching to uart2")

        iot.sleep(tm2)
        uart1:pipe(nil)        
        log.info(tag, "switching to uart1")

    end

end)
