local tag = "gnss"
local gnss = {}

local configs = require("configs")

local default_config = {
    enable = false, -- 启用
    uart = 2, -- 串口
    baudrate = 115200 -- 速度
}

local config = {}


--- 初始化GPS
function gnss.init()
    local ret

    -- 加载配置
    ret, config = configs.load(tag)
    if not ret then
        -- 使用默认
        config = default_config
    end

    if not config.enable then
        return
    end

    log.info(tag, "init")

    -- 初始化

    uart.setup(config.uart, config.baudrate)
    libgnss.bind(config.uart)
    -- libgnss.debug(true) --GPS调试

    sys.subscribe("config_STATE", function(event, ticks)
        -- event取值有
        -- FIXED 定位成功
        -- LOSE  定位丢失
        -- ticks是事件发生的时间,一般可以忽略
        log.info(tag, "state", event, ticks)
        if event == "FIXED" then
            sys.publish("config_OK")
        end
    end)
end

-- 是否定位成功
function gnss.isValid()
    return libgnss.isFix()
end

--- 获取GPS定位
--- @return boolean 成功与否
--- @return table
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
function gnss.get()
    if libgnss.isFix() then
        return true, libgnss.getRmc(2)
    end
    return false
end

--- 关闭GPS
function gnss.close()

end

return gnss
