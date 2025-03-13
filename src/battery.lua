--- 电池相关
--- @module "battery"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "battery"
local battery = {}

local configs = require("configs")

local default_config = {
    enable = true, -- 启用
    vbat = 3800, -- 供电电压mV（合宙的推荐设计是4.2）
    voltage = 12000, -- 电池电压
    empty = 11200, -- 空的电压
    full = 14200 -- 满的电压
}

local config = {}

--- 电池初始化
function battery.init()
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

    adc.open(adc.CH_VBAT)
    local vbat = adc.get(adc.CH_VBAT)
    adc.close(adc.CH_VBAT)

    log.info(tag, "init", vbat) --测试值 3835
end

--- 获取电池电量
--- @return boolean 成功与否
--- @return table 百分比
function battery.get()
    if not config.enable then
        return false
    end

    -- adc.setRange(config.range) -- 0-1.2v
    adc.open(adc.CH_VBAT)
    local vbat = adc.get(adc.CH_VBAT)
    adc.close(adc.CH_VBAT)
        
    -- 计算电压和百分比
    local voltage = config.voltage * vbat / config.vbat
    local percent = (voltage - config.empty) / (config.full - config.empty) * 100
    log.info(tag, "get", vbat, voltage, percent)

    return true, {
        vbat = vbat,
        voltage = voltage,
        percent = percent,
    }
end

return battery
