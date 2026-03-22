local sensor = {}

local tag = "sensor"

local settings = require "settings"
local cron = require "cron"

-- 串口3接单片机
local uart_id = 3

-- 重量和计数
local weight = 0
local correct = 0

local ticks = 0
local rounds = 0

local _position = 0

sensor.feed_rounds = 0
-- 饲料电机磁感应
sensor.feed_sensor = iot.gpio(13, {
    debounce = 50,
    when = "FALLING", -- 下降触发
    callback = function(level, pin)
        sensor.feed_rounds = sensor.feed_rounds + 1
    end
})

-- 当前重量 g
function sensor.weight()
    return weight + correct
end

-- 当前位置 cm
function sensor.position()
    return _position
end

-- 编码器脉冲数
function sensor.ticks()
    return ticks
end
function sensor.rounds()
    return rounds
end

-- 设置当前位置
function sensor.set_position(p)
    _position = p

    -- 反推当前位置
    if settings.encoder and settings.encoder.enable then
        if p == 0 then
            sensor.reset()
            -- 重复设置2次，避免未生效
            iot.setTimeout(sensor.reset, 100)
            iot.setTimeout(sensor.reset, 200)
        end
        -- 编码器 每圈100脉冲
        ticks = p / math.pi / 8 * settings.encoder.pulse

        -- 向编码器设置值
        uart.write(uart_id, json.encode({
            type = "set",
            ticks = ticks
        }))
        uart.write(uart_id, json.encode({
            type = "set",
            ticks = ticks
        }))
    end
end

function sensor.add_position(v)
    _position = _position + v
end

-- 处理单片机消息
local handlers = {}
function handlers.status(data)
    -- log.info("on_status", data.weight, data.ticks) 日志太多了
    weight = data.weight
    ticks = data.ticks
    rounds = data.rounds
    -- sensor.c1 = data.c1
    -- sensor.c2 = data.c2

    if settings.encoder and settings.encoder.enable then
        -- 编码器 每圈100脉冲
        _position = ticks * math.pi * 8 / settings.encoder.pulse
        if settings.encoder.reverse then
            _position = -_position
        end
    end
end

function handlers.init(data)
    if settings.encoder.enable then
        -- 向编码器回写值
        sensor.set_position(_position)
    end
    iot.emit("error", "单片机重启了")
end

local cache = ""
local function on_data(id, len)
    local data = uart.read(id, len)
    -- log.info("receive", len, data) 日志太多了

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
                local ret, response = xpcall(handler, iot.traceback, pkt)
                if not ret then
                    log.info(response)
                end
            else
                log.info("unknown command", cache)
            end
        end

        cache = ""
    end
end

-- 连接单片机
uart.setup(uart_id, 115200)
uart.on(uart_id, "receive", on_data)

-- 清空计数
function sensor.reset()
    uart.write(uart_id, json.encode({
        type = "reset"
    }))
end

-- 去皮
function sensor.tare()
    correct = 0
    weight = 0
    sensor.save()
    uart.write(uart_id, json.encode({
        type = "tare"
    }))
end

-- 校准
function sensor.calibrate(weight)
    correct = 0
    sensor.save()
    uart.write(uart_id, json.encode({
        type = "calibrate",
        weight = weight
    }))
end

-- 问重量
local query_cmd = iot.json_encode({
    type = "status"
})
function sensor.query_status()
    uart.write(uart_id, query_cmd)
end

-- 自动校正重量到目标值
function sensor.correct(target, step)
    if sensor.weight() < target then
        correct = correct + step
        -- 加过头了
        if sensor.weight() > target then
            correct = target - weight
        end
    elseif sensor.weight() > target then
        correct = correct - step
        -- 减过头了
        if sensor.weight() < target then
            correct = target - weight
        end
    end
end

-- 初始化KV数据库
fskv.init()

-- 读取修正值
correct = fskv.get("correct") or 0
_position = fskv.get("position") or 0
log.info("fskv", correct, _position)

-- 保存值
function sensor.save()
    fskv.set("position", _position)
    fskv.set("correct", correct)
end

-- 重启前保存值
iot.on("REBOOT", sensor.save)

-- 每天保存一次修正值
-- iot.setInterval(sensor.save, 24 * 3600)
cron.clock("00:00", sensor.save)

-- 100ms向单片机询问一次数据
iot.setInterval(sensor.query_status, 200)

return sensor
