local tjc = {}
local tag = "tjc"

local uart_id = 1

local pages = {}
local page = {}

local commands = {}

local function on_data(id, len)
    local data = uart.read(id, len)
    log.info(tag, "receive", len, data)

    if data:startsWith("{") and data:endsWith("}") then
        local pkt, ret, err = json.decode(data)
        if ret ~= 1 then
            log.info(tag, "json decode error", err)
            return
        end

        -- 处理页面切换
        if pkt.type == "page" then
            log.info(tag, "page", pkt.page)

            -- 卸载旧页面
            if type(page.unmount) == "function" then
                local ret, err = pcall(page.unmount)
                if not ret then
                    log.info(tag, "handle page unmount error", err)
                end
            end

            -- 更新页面
            page = pages[pkt.page] or {}

            -- 挂载新页面
            if type(page.mount) == "function" then
                local ret, err = pcall(page.mount)
                if not ret then
                    log.info(tag, "handle page mount error", err)
                end
            end

            -- 刷新新页面
            if type(page.refresh) == "function" then
                local ret, err = pcall(page.refresh)
                if not ret then
                    log.info(tag, "handle page refresh error", err)
                end
            end
            return
        end

        -- 处理命令（比如按钮）
        local handler = commands[pkt.type]
        if handler then
            local ret, err = pcall(handler, pkt)
            if not ret then
                log.info(tag, "handle command error", err)
            end
        end
    end
end

function tjc.init(uartid, baudrate)
    uart_id = uartid or 1

    -- 连接串口屏
    uart.setup(uart_id, baudrate or 115200, 8, 1, uart.NONE)
    uart.on(uart_id, "receive", on_data)

    -- 屏幕刷新
    iot.start(function()
        while true do
            iot.sleep(1000)

            -- 刷新新页面
            if type(page.refresh) == "function" then
                local ret, err = pcall(page.refresh)
                if not ret then
                    log.info(tag, "handle page refresh error", err)
                end
            end
        end
    end)
end

-- 注册页面
function tjc.register(name, refresh, mount, unmount)
    pages[name] = {
        refresh = refresh,
        mount = mount,
        unmount = unmount
    }
end

-- 设置文本
function tjc.set_text(name, value)
    local str = name .. ".txt=" .. "\"" .. value .. "\""
    uart.write(uart_id, str .. "\xff\xff\xff")
    -- log.info(tag, "set_text", str)
end

-- 设置值
function tjc.set_value(name, value)
    if type(value) == "boolean" then
        value = value and 1 or 0
    end

    -- uart.write(uart_id, name .. ".val=" .. value .. "\xff\xff\xff")
    local str = name .. ".val=" .. math.floor(value)
    uart.write(uart_id, str .. "\xff\xff\xff")
    -- log.info(tag, "set_value", str)
end

-- 设置布尔值
function tjc.set_bool(name, value)
    value = value and 1 or 0
    local str = name .. ".val=" .. math.floor(value)
    uart.write(uart_id, str .. "\xff\xff\xff")
    -- log.info(tag, "set_bool", str)
end

return tjc
