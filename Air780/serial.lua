local tag = "SERIAL"

local function serial_event_handle(id, len)
    -- local data = uart.read(id, len)
    local data = ""
    local s = ""
    repeat
        s = uart.read(id, 128)
        if #s > 0 then
            data = data .. s
        end
    until s == ""
    
    sys.publish("serial_data", id, data)
end

function serial_open(id, cfg)

    local parity
    if cfg.parity == 'N' or cfg.parity == 'n' then
        parity = uart.NONE
    elseif cfg.parity == 'E' or cfg.parity == 'e' then
        parity = uart.Even
    elseif cfg.parity == 'O' or cfg.parity == 'o' then
        parity = uart.Odd
    else
        parity = uart.NONE
    end

    local ret
    if cfg.rs485_gpio == nil then
        ret = uart.setup(id, cfg.baud_rate, cfg.data_bits, cfg.stop_bits, parity)
    else
        ret = uart.setup(id, cfg.baud_rate, cfg.data_bits, cfg.stop_bits, parity, uart.MSB, 1024, cfg.rs485_gpio)
    end

    uart.on(id, 'receive', serial_event_handle)

    log.info(tag, "open serial", id, json.encode(cfg), ret)

    return ret == 0
end

function serial_write(id, data)
    return uart.write(id, data)
end

function serial_read(id, len)
    return uart.read(id, len)
end

function serial_close(id)
    log.info(tag, "close serial", id)
    uart.close(id)
end

