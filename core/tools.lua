--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 虚拟串口处理指令
-- @module tools
local tools = {}

local tag = "tools"

local commands = require("commands")

local cache = ""
local function on_data(id, len)
    local data = uart.read(id, len)
    log.info(tag, "receive", len, data)

    if data:startsWith("\r\n") then
        cache = data
    elseif #cache > 0 then
        cache = cache .. data
    end

    local response

    if data:endsWith("\r\n") then
        local pkt, ret, err = json.decode(cache:sub(3, -3))
        if ret == 1 then
            local handler = commands[pkt.cmd]
            if handler then
                --response = handler(pkt)
                --加入异常处理
                ret, response = pcall(handler, pkt)
                if not ret then
                    response = commands.error(response)
                end
            else
                response = commands.error("invalid command")
            end
        else
            response = commands.error(err)
        end
        cache = ""

        if response ~= nil then
            local data2, err2 = json.encode(response)
            if data2 == nil then
                response = commands.error("json encode failed" .. err2)
                data2 = json.encode(response)
            end
            uart.write(uart.VUART_0, "\r\n" .. data2 .. "\r\n")
        end
    end
end

function tools.init()
    uart.setup(uart.VUART_0)
    uart.on(uart.VUART_0, "receive", on_data)
end

-- 启动
tools.init()

return tools
