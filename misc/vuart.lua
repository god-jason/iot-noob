--- USB虚拟串口，调试工具用
-- @module vuart
local vuart = {}

local log = iot.logger("vuart")

local agent = require("agent")

local function reply_ok()

end

local function reply_error(err)
    return {
        error = err
    }
end

local cache = ""
local function on_data(id, len)
    local data = uart.read(id, len)
    log.info("receive", len, data)

    if #cache > 0 then
        cache = cache .. data
    else
        cache = data
    end

    -- 防止命令过长
    if #cache > 4096 then
        cache = ""
        local response = reply_error("command too long")
        local data2 = json.encode(response)
        uart.write(uart.VUART_0, data2 .. "\r\n")
    end

    if data:endsWith("\r\n") then
        if #cache == 2 then
            cache = ""
            return
        end

        local response

        local pkt, ret, err = json.decode(cache:sub(1, -3))
        cache = ""

        if ret == 1 then
            ret, err = agent.execute(pkt.type, pkt)
            if ret then
                response = reply_error(err)
            else
                response = reply_ok(err)
            end
        else
            response = reply_error(err)
        end

        if response ~= nil then
            local data2, err2 = json.encode(response)
            if data2 == nil then
                response = reply_error("json encode failed" .. err2)
                data2 = json.encode(response)
            end
            uart.write(uart.VUART_0, data2 .. "\r\n")
        end
    end
end

uart.setup(uart.VUART_0)
uart.on(uart.VUART_0, "receive", on_data)

return vuart
