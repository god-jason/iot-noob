local tag = "serial"
local serial = {}

local configs = require("configs")

local default_config = {
    enable = true, -- 启用
    ports = {{
        id = 0,
        name = "RS485",
        rs485_gpio = 22
    }, {
        id = 1,
        name = "RS232"
    }}
}

local config = {}

function serial.init()
    local ret

    -- 加载配置
    ret, config = configs.load(tag)
    if not ret then
        -- 使用默认
        config = default_config
    end

    if not config.enable then
        return
    end

    log.info(tag, "init")
end

function serial.open(id, baud_rate, data_bits, stop_bits, parity)

    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    local p = uart.NONE
    if parity == 'N' or parity == 'n' then
        p = uart.NONE
    elseif parity == 'E' or parity == 'e' then
        p = uart.Even
    elseif parity == 'O' or parity == 'o' then
        p = uart.Odd
    end

    local ret
    if port.rs485_gpio == nil then
        ret = uart.setup(port.id, baud_rate, data_bits, stop_bits, p)
    else
        ret = uart.setup(port.id, baud_rate, data_bits, stop_bits, p, uart.MSB, 1024, port.rs485_gpio)
    end

    return ret == 0
end

function serial.write(data)
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end
    
    local len = uart.write(port.id, data)
    return len > 0, len
end

function serial.read()
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    local len = uart.rxSize(port.id)
    if len > 0 then
        local data = uart.read(port.id, len)
        return true, data
    end
    return false
end

function serial.watch(id, cb)
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    uart.on(self.id, 'receive', cb)
    return true
end

function serial.close(id)
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    uart.close(port.id)
    return true
end

return serial
