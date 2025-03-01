local tag = "BATTERY"

local id = 0 --adc.CH_VBAT
local zero = 11.2
local full = 14.2

function get()
    adc.setRange(adc.ADC_RANGE_1_2) -- 0-1.2v
    local ret = adc.open(id)
    if not ret then        return false    end
    local vbat = adc.get(id)
    if vbat < 0 then        return false    end

    adc.close(id)

    local voltage = full * vbat / 1024
    local percent = (voltage - zero) /(full - zero) * 100
    log.info(tag, "get", vbat, voltage, percent)

    return true, percent
end
