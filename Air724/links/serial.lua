--- 模块功能：串口连接
-- @module serial
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30
local MOD = "SERIAL"

require "config"

local uarts = {
    -- 某些板为 2 pio.P0_23
    [1] = {rs485 = true, rs485_en = pio.P0_0},
    [2] = {},
    [3] = {}
}

(function()
    local ok, res = config.load("uarts")
    if ok then uarts = res end
end)()

--串口类
Serial = {}

-- 配置模板
local _template = {
    -- 串口号 1 2 3
    uart = 1,
    -- 波特率
    baud = 9600,
    -- 字长
    bits = 8,
    -- 校验，0 none 无校验, 1 odd 奇校验, 2 even 偶校验
    parity = 0,
    -- 结束符 1, 2, 0.5=>0xf0, 1.5=>0xf1
    stop = 1
    -- 读超时
    -- timeout = 2000
}

function Serial:new(args)
    local obj = args or {}
    self.__index = self
    setmetatable(obj, Serial)
    obj.uart = obj.uart or 1 -- 默认1号
    obj.baud = obj.baud or 9600
    obj.bits = obj.bits or 8
    obj.parity = obj.parity or 0
    obj.stop = obj.stop or 1
    return obj
end

function Serial:open()
    -- 配置并且打开串口
    uart.setup(self.uart, self.baud, self.bits, self.parity, self.stop, nil, 1)

    local u = uarts[self.uart]
    if u.rs485 then
        -- RS485使能（收发电平翻转）
        --uart.set_rs485_oe(self.uart, u.rs485_en, 1, 1, 1)
        uart.set_rs485_oe(self.uart, u.rs485_en)
    end

    self.opened = true

    -- 监听端口消息(会产生重复监听的问题)
    uart.on(self.uart, "receive",
            function() sys.publish("UART_RECEIVE_" .. self.uart) end)

    sys.taskInit(function()
        local buf = ""
        while self.opened do
            local s = uart.read(self.uart, 1)
            if s == "" then
                -- 等待485帧间隔
                if not sys.waitUntil("UART_RECEIVE_" .. self.uart,
                                     35000 / config.baud) then
                    if buf:len() > 0 then
                        sys.publish("UART_DATA_" .. self.uart, buf)
                        buf = ""
                    end
                else
                    -- TODO 有没有必要？？
                    buf = buf .. s
                end
            else
                buf = buf .. s
            end
        end

    end)
end

function Serial:close() self.opened = false end

function Serial:read(timeout)
    return sys.waitUntil("UART_DATA_" .. self.uart, timeout)
end

function Serial:write(data) return uart.write(self.uart, data) end

