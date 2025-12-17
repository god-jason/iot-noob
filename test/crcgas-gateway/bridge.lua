local tag = "bridge"

local gateway = require("gateway")

-- 透传时间 2s
local pipe_timeout = 5000

iot.start(function()
    -- 等待网关启动完成
    iot.wait("GATEWAY_READY")

    log.info(tag, "start bridge")

    local uart1 = gateway.get_link_instanse("RS485-1")
    local uart2 = gateway.get_link_instanse("RS485-2")

    log.info(tag, "uart1", uart1, "uart2", uart2)

    local piping = false
    local pipe_start = 0

    -- 监听uart2
    iot.on("uart_receive_2", function()
        if piping then
            return
        end
        log.info(tag, "start piping from uart2 vs uart1")

        piping = true
        pipe_start = mcu.ticks()

        -- 每一个数据包要转发
        local ret, data = uart2:read()
        if ret and data then
            uart1:write(data)
        end

        -- 开启透传
        uart1:pipe(uart2)
    end)

    while true do
        local now = mcu.ticks()

        if piping then
            local remain = pipe_timeout - (now - pipe_start)
            if remain <= 0 then
                log.info(tag, "pipe timeout, stop piping")
                -- 超时，关闭透传
                piping = false
                uart1:pipe(nil)
                iot.sleep(pipe_timeout)
            else
                --log.info(tag, "piping, sleep briefly", remain)
                iot.sleep(remain)
            end
        else
            --log.info(tag, "not piping, sleep")
            iot.sleep(pipe_timeout)
        end
    end

end)
