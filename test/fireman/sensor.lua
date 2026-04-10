local sensor = {}

local tag = "sensor"

local settings = require "settings"
local configs = require "configs"

-- 串口2接单片机
local uart_id = 2

-- 距离和温度数据
sensor.distance = 0
sensor.temperature = 0

-- 处理单片机消息
local handlers = {}
function handlers.status(data)
    sensor.temperature = data.temperature or 0

    -- 检查并转换距离值
    local distance = data.distance
    if distance == nil then
        return
    end
    
    -- 转换为数字
    distance = tonumber(distance)
    if distance == nil then
        return
    end
    
    -- 过滤异常值：SR04有效范围是2-400cm，这里放宽到0-500cm
    -- 如果值异常大（可能是解析错误或数据损坏），则忽略
    if distance < 0 or distance > 500 then
        return  -- 静默忽略异常值
    end
    
    sensor.distance = distance
end

local cache = ""
local function on_data(id, len)
    local data = uart.read(id, len)
    -- log.info(tag, "receive", len, data) 日志太多了

    if #cache > 0 then
        cache = cache .. data
    else
        cache = data
    end

    -- 防止命令过长
    if #cache > 4096 then
        cache = ""
        return
    end

    -- 只解析花括号结束（JSON过长有一定概率误判）
    if data:endsWith("}") then
        if #cache == 2 then
            cache = ""
            return
        end

        local pkt, ret, err = json.decode(cache)

        if ret == 1 then
            local handler = handlers[pkt.type]
            if handler then
                -- response = handler(pkt)
                -- 加入异常处理
                local ret, response = pcall(handler, pkt)
                if not ret then
                    log.info(tag, response)
                end
            else
                log.info(tag, "unknown command", cache)
            end
        end

        cache = ""
    end
end

-- 连接单片机
uart.setup(uart_id, 115200)
uart.on(uart_id, "receive", on_data)


-- 问状态
function sensor.query_status()
    uart.write(uart_id, json.encode({
        type = "status"
    }))
end

-- 100ms向单片机询问一次
iot.setInterval(sensor.query_status, 100)


return sensor
