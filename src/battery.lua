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
    adc = 1, -- 内置ADC 0 1
    bits = 10, -- 精度，默认10->1023
    range = adc.ADC_RANGE_1_2, -- 范围
    voltage = 12, -- 电池电压
    empty = 11.2, -- 空的电压
    full = 14.2 -- 满的电压
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

    log.info(tag, "init")
end

--- 获取电池电量
--- @return boolean 成功与否
--- @return number 百分比
function battery.get()
    if not config.enable then
        return false
    end

    adc.setRange(config.range) -- 0-1.2v

    local ret = adc.open(config.adc)
    if not ret then return false end
    local vbat = adc.get(config.adc)
    adc.close(config.adc)
    if vbat < 0 then return false end

    -- 计算电压和百分比
    local voltage = config.full * vbat / 1024
    local percent = (config.voltage - config.empty) / (config.full - config.empty) * 100
    log.info(tag, "get", vbat, voltage, percent)

    return true, percent
end

return battery