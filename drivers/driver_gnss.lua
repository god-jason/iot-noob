--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- GPS相关
-- @module gnss
local gnss = {}

local tag = "gnss"

local led = require("led")

local configs = require("configs")

local default_options = {
    enable = false, -- 启用
    debug = false,
    uart = 2, -- 串口
    baud_rate = 115200 -- 速度
}

local options = {}

--- 初始化GPS
function gnss.init()
    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    log.info(tag, "init", json.encode(options))

    -- 给内置GPS芯片上电
    pm.power(pm.GPS, true)

    -- 初始化
    libgnss.clear() -- 清空数据,兼初始化

    uart.setup(options.uart, options.baud_rate)
    libgnss.bind(options.uart)
    -- libgnss.bind(options.uart, uart.VUART_0) --调试原始数据
    libgnss.debug(options.debug) -- GPS调试

    sys.subscribe("GNSS_STATE", function(event, ticks)
        -- event取值有
        -- FIXED 定位成功
        -- LOSE  定位丢失
        -- ticks是事件发生的时间,一般可以忽略
        log.info(tag, "state", event, ticks)
        if event == "FIXED" then
            led.on("gnss")
            sys.publish("GNSS_OK")
        end
    end)

end

-- 是否定位成功
function gnss.isValid()
    return libgnss.isFix()
end

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

--- 获取GPS定位
-- @return boolean 成功与否
-- @return table
function gnss.get()
    log.info(tag, "get", libgnss.getIntLocation())
    -- log.info(tag, json.encode(libgnss.getRmc(2)))

    if libgnss.isFix() then
        local lat, lng, speed = libgnss.getIntLocation()
        return true, {
            langitude = lng,
            latitude = lat,
            speed = speed
        }
        -- return true, libgnss.getRmc(2)
    end
    return false
end

--- 关闭GPS
function gnss.close()
    pm.power(pm.GPS, false)
end

-- 启动
gnss.init()

return gnss
