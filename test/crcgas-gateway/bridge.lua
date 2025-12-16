local tag = "bridge"

-- UART2 for RS485
local ret, serial = iot.uart(2, {
    baud = 9600,
    databits = 8,
    parity = "N",
    stopbits = 1,
    rs485_gpio= 10,
})


iot.start(function()
    log.info(tag, "started")
    while true do

        serial:wait()

        local ret, data = serial:read()
        if ret and data then


            uart.write(1, data)
        end

    end
end)
