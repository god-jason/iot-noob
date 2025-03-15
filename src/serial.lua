--- 串口相碰
--- @module "serial"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "serial"
local serial = {}

local configs = require("configs")

local default_config = {
    enable = true, -- 启用
    ports = {{
        id = 1,
        name = "RS485",
        -- rs485_gpio = 22
    }, {
        id = 2,
        name = "GNSS"
    }, {
        id = 3,
        name = "RS232"
    }}
}

local config = {}

--- 串口初始化
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

---打开串口
---@param id integer ID
---@param baud_rate integer 波特率
---@param data_bits integer 数据位
---@param stop_bits integer 停止位
---@param parity string 检验位 N E O
---@return boolean 成功与否
function serial.open(id, baud_rate, data_bits, stop_bits, parity)

    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    --log.info(tag, "open", port.id, port.name, baud_rate, data_bits, stop_bits, parity)

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

    log.info(tag, "open", port.id, port.name, baud_rate, data_bits, stop_bits, parity, ret==0)

    return ret == 0
end

---写入串口数据
---@param data string 写入数据
---@return boolean 成功与否
---@return integer|nil 写入的长度
function serial.write(data)
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end
    
    local len = uart.write(port.id, data)
    log.info(tag, "write", port.id, data, len)
    return len > 0, len
end

---读取串口数据
---@param id integer ID号 
---@return boolean 成功与否
---@return string|nil 内容
function serial.read(id)
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
        log.info(tag, "read", port.id, data)
        return true, data
    end
    return false
end

---监听串口数据
---@param id integer ID号 
---@param cb function 回调
---@return boolean 成功与否
function serial.watch(id, cb)
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    uart.on(port.id, 'receive', cb)
    return true
end

---关闭串口
---@param id integer ID号 
---@return boolean 成功与否
function serial.close(id)
    if not config.enable then
        return false
    end

    local port = config.ports[id]
    if not port then
        return false
    end

    log.info(tag, "close", port.id)

    uart.close(port.id)
    return true
end

return serial
