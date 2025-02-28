
local tag = "GNSS"
local uart_id, uart_baudrate = 1, 115200

-- 初始化
function init()
    uart.setup(uart_id, uart_baudrate)
    libgnss.bind(uart_id)
    --libgnss.debug(true) --GPS调试
end

-- 是否定位成功
function isValid()
    return libgnss.isFix()
end

-- 获取GPS定位
--[[
{
    "course":0,
    "valid":true,   // true定位成功,false定位丢失
    "lat":23.4067,  // 纬度, 正数为北纬, 负数为南纬
    "lng":113.231,  // 经度, 正数为东经, 负数为西经
    "variation":0,  // 地面航向，单位为度，从北向起顺时针计算
    "speed":0       // 地面速度, 单位为"节"
    "year":2023,    // 年份
    "month":1,      // 月份, 1-12
    "day":5,        // 月份天, 1-31
    "hour":7,       // 小时,0-23
    "min":23,       // 分钟,0-59
    "sec":20,       // 秒,0-59
}
]]
function get()
    if libgnss.isFix() then
        return true, libgnss.getRmc(2)
    end
    return false
end

sys.subscribe("GNSS_STATE", function(event, ticks)
    -- event取值有
    -- FIXED 定位成功
    -- LOSE  定位丢失
    -- ticks是事件发生的时间,一般可以忽略
    log.info(tag, "state", event, ticks)
    if event == "FIXED" then
        sys.publish("GNSS_OK")
    end
end)

