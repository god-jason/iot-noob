local tag = "tools"
local tools = {}
local handlers

local utils = require("utils")
local configs = require("configs")

local function write_packet(pkt)
    local data = json.encode(pkt)
    uart.write(uart.VUART_0, "\r\n" .. data .. "\r\n")
end

local function response(ret, msg, data)
    write_packet({
        ret = ret,
        msg = msg,
        data = data
    })
end

local function response_data(data)
    response(1, nil, data)
end

local function response_ok(msg)
    response(1, msg)
end

local function response_error(msg)
    response(0, msg)
end

local function on_hello()
    response_ok("world")
end

local function on_commands()
    local cmds = {}
    for k, v in pairs(handlers) do
        table.insert(cmds, k)
    end
    response_data(cmds)
end

local function on_version()
    response_data(_G.PROJECT .. _G.VERSION)
end

local function on_reboot(msg)
    response_ok("reboot after 5s")
    sys.timerStart(rtos.reboot, 5000)
end

local function on_clear_fs()
    utils.remove_all("/")
    -- utils.walk("/")
    response_ok("clear_fs finished")
end

local function on_read_config(msg)
    local ret, data, path = configs.load(msg.name)
    if ret then
        response(1, path, data)
    else
        response_error("not found")
    end
end

local function on_write_config(msg)
    local ret, path = configs.save(msg.name, msg.data)
    if ret then
        response_ok(path)
    else
        response_error("write failed")
    end
end

local function on_walk(msg)
    local files = {}
    utils.walk(msg.data or "/", files)
    response_data(files)
end

handlers = {
    hello = on_hello,
    commands = on_commands,
    version = on_version,
    reboot = on_reboot,
    clear_fs = on_clear_fs,
    read_config = on_read_config,
    write_config = on_write_config,
    walk = on_walk
}

local cache = ""
local function on_data(id, len)
    local data = uart.read(id, len)
    log.info(tag, "command", len, data)

    if data:startsWith("\r\n") then
        cache = data
    elseif #cache > 0 then
        cache = cache .. data
    end

    if data:endsWith("\r\n") then
        local pkt, ret, err = json.decode(cache:sub(3, -3))
        if ret == 1 then
            local handler = handlers[pkt.cmd]
            if handler then
                handler(pkt)
            else
                response_error("invalid command")
            end
        else
            response_error(err)
        end
        cache = ""
    end
end

function tools.init()
    uart.setup(uart.VUART_0)
    uart.on(uart.VUART_0, "receive", on_data)
end

return tools
