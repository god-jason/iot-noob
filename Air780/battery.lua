local tag = "BATTERY"

--- 获取电池电量
--- @return boolean 成功与否
--- @return number 百分比
function get()
    if not BATTERY.enable then
        return false
    end

    adc.setRange(BATTERY.range) -- 0-1.2v

    local ret = adc.open(BATTERY.adc)
    if not ret then return false end
    local vbat = adc.get(BATTERY.adc)
    adc.close(BATTERY.adc)
    if vbat < 0 then return false end

    -- 计算电压和百分比
    local voltage = BATTERY.full * vbat / 1024
    local percent = (BATTERY.voltage - BATTERY.empty) / (BATTERY.full - BATTERY.empty) * 100
    log.info(tag, "get", vbat, voltage, percent)

    return true, percent
end
