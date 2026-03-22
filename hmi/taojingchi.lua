--- 陶晶驰串品屏
-- @module tjc
local tjc = {}
local log = iot.logger("taojingchi")

local settings = require("settings")
local agent = require("agent")
local boot = require("boot")
local utils = require("utils")

local options = {}

local pages = {}
local current_page = {}

--[[
淘晶驰串口屏操作库，淘宝卖的最多，开发简单

本库对串口屏操作进行封装，使用json包方式进行交互，简化程序逻辑。
由于串口屏不支持json，所以需要自行拼包，如果格式错误，会通讯失败

编程指导：
0、Program.s中需要指定波特率，否则会通讯失败
baud=115200

1、页面切换需要发送切换指令，写在后初始化事件脚本中
prints "{\"type\":\"page\", \"value\":\"home\"}",0

2、按钮事件，在弹起事件脚本中写
beep 100
prints "{\"type\":\"stop\",\"data\":{\"value\":1}}",0

3、状态开关，在弹起事件脚本中写
beep 100
if('&val&'>0)
{
  prints "{\"type\":\"feed_forward\",\"data\":{\"value\":true}}",0
}else
{
  prints "{\"type\":\"feed_forward\",\"data\":{\"value\":false}}",0
}

4、进度条，在弹起事件中，需要先转换数值为字符串

5、修改界面的接口
tjc.set_text，修改文本值
tjc.set_value，修改值（注意，串口屏无浮点数概念，传值需要使用整数，屏程序按配置显示小数点位置）
tjc.set_bool，修改布尔值


]] --

--- 注册页面
-- @param name
-- @param page
function tjc.register(name, page)
    pages[name] = page
end

local function on_data(id, len)
    local data = uart.read(id, len)
    log.info("receive", len, data)

    -- TODO 此处没有解决粘包和拆包问题
    if data:startsWith("{") and data:endsWith("}") then
        local pkt, ret, err = json.decode(data)
        if ret ~= 1 then
            log.info("json decode error", err)
            return
        end

        -- 处理页面切换
        if pkt.type == "page" then
            log.info("page", pkt.page)

            -- 卸载旧页面
            if type(current_page.leave) == "function" then
                ret, err = xcall(current_page.leave, utils.traceback)
                if ret == false then
                    log.error("handle page leave error", err)
                end
            end

            -- 更新页面
            current_page = pages[pkt.page] or {}

            -- 挂载新页面
            if type(current_page.enter) == "function" then
                ret, err = xpcall(current_page.enter, utils.traceback)
                if ret == false then
                    log.error("handle page enter error", err)
                end
            end

            -- 刷新新页面
            if type(current_page.tick) == "function" then
                ret, err = xpcall(current_page.tick, utils.traceback)
                if ret == false then
                    log.error("handle page tick error", err)
                end
            end
            return
        end

        -- 处理命令（比如按钮）
        ret, err = agent.execute(pkt.type, pkt)
        if not ret then
            log.info("handle command error", err)
        end
    end
end

--- 打开
function tjc.open()
    options = settings.taojingchi

    -- 连接串口屏
    uart.setup(options.uart_id, options.baud_rate or 115200, 8, 1, uart.NONE)
    uart.on(options.uart_id, "receive", on_data)

    -- 屏幕刷新
    iot.start(function()
        while true do
            iot.sleep(1000)

            -- 刷新新页面
            if type(current_page.tick) == "function" then
                ---local ret, err = utils.call(current_page.tick)
                local ret, err = xpcall(current_page.tick, utils.traceback)
                if ret == false then
                    log.error("handle page tick error", err)
                end
            end
        end
    end)

    return true
end

--- 设置文本
-- @param name 控件ID
-- @param value 值
function tjc.set_text(name, value)
    local str = name .. ".txt=" .. "\"" .. value .. "\""
    uart.write(options.uart_id, str .. "\xff\xff\xff")
    -- log.info("set_text", str)
end

--- 设置值
-- @param name 控件ID
-- @param value 值
function tjc.set_value(name, value)
    if type(value) == "boolean" then
        value = value and 1 or 0
    end

    -- uart.write(uart_id, name .. ".val=" .. value .. "\xff\xff\xff")
    local str = name .. ".val=" .. math.floor(value)
    uart.write(options.uart_id, str .. "\xff\xff\xff")
    -- log.info("set_value", str)
end

--- 设置布尔值
-- @param name 控件ID
-- @param value 值
function tjc.set_bool(name, value)
    value = value and 1 or 0
    local str = name .. ".val=" .. math.floor(value)
    uart.write(options.uart_id, str .. "\xff\xff\xff")
    -- log.info("set_bool", str)
end

--- 切换页面
-- @param name 页面名称
function tjc.set_page(name)
    local str = "page=" .. name
    uart.write(options.uart_id, str .. "\xff\xff\xff")
end

tjc.deps = {"settings"}

settings.register("taojingchi", {
    uart_id = 1,
    baud_rate = 115200
})

boot.register("taojingchi", tjc)

return tjc
