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
    ports = {{
        enable = true, -- 启用
        name = "RS485",
        -- rs485_gpio = 22
    }, {
        enable = false, -- 启用
        name = "GNSS"
    }, {
        enable = true, -- 启用
        name = "RS232"
    }}
}

local config = {}

--- 串口初始化
function serial.init()

    log.info(tag, "init")
    
    -- 加载配置
    config = configs.load_default(tag, default_config)
    if not config.enable then
        return
    end

end

--- 检查可用
---@param id number
---@return boolean
function serial.available(id)
    local port = config.ports[id]
    if not port then
        log.info(tag, id, "not found")
        return false
    end
    if not port.enable then
        log.info(tag, id, "disabled")
        return false
    end
    return true
end

---打开串口
---@param id integer ID
---@param baud_rate integer 波特率
---@param data_bits integer 数据位
---@param stop_bits integer 停止位
---@param parity string 检验位 N E O
---@return boolean 成功与否
function serial.open(id, baud_rate, data_bits, stop_bits, parity)
    if not serial.available(id) then
        return false
    end
    
    local port = config.ports[id]
    --log.info(tag, "open", port.id, port.name, baud_rate, data_bits, stop_bits, parity)

    local p = uart.NONE
    if parity == 'N' or parity == 'n' then
        p = uart.NONE
    elseif parity == 'E' or parity == 'e' then
        p = uart.EVEN
    elseif parity == 'O' or parity == 'o' then
        p = uart.ODD
    end

    local ret
    if port.rs485_gpio == nil then
        ret = uart.setup(id, baud_rate, data_bits, stop_bits, p)
    else
        ret = uart.setup(id, baud_rate, data_bits, stop_bits, p, uart.MSB, 1024, port.rs485_gpio)
    end

    log.info(tag, "open", id, port.name, baud_rate, data_bits, stop_bits, parity, ret==0)

    return ret == 0
end

---写入串口数据
---@param data string 写入数据
---@return boolean 成功与否
---@return integer|nil 写入的长度
function serial.write(id, data)
    if not serial.available(id) then
        return false
    end
    
    local len = uart.write(id, data)
    log.info(tag, "write", id, data, len)
    return len > 0, len
end

---读取串口数据
---@param id integer ID号 
---@return boolean 成功与否
---@return string|nil 内容
function serial.read(id)
    if not serial.available(id) then
        return false
    end

    local len = uart.rxSize(id)
    if len > 0 then
        local data = uart.read(id, len)
        log.info(tag, "read", id, data)
        return true, data
    end
    return false
end

---监听串口数据
---@param id integer ID号 
---@param cb function 回调
---@return boolean 成功与否
function serial.watch(id, cb)
    if not serial.available(id) then
        return false
    end

    uart.on(id, 'receive', cb)
    return true
end

---关闭串口
---@param id integer ID号 
---@return boolean 成功与否
function serial.close(id)
    if not serial.available(id) then
        return false
    end

    log.info(tag, "close", id)

    uart.close(id)
    return true
end

return serial
