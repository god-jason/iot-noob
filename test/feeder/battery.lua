local battery = {}
local tag = "battery"

local Led = require "led"
local settings = require("settings")
local boot = require("boot")

battery.charging = false

-- 充电（常闭继电器）
function battery.charge(onoff)
    log.info("charge", onoff)
    battery.charging = onoff
    if onoff then
        components.charge:turn_off()
        components.led_power:blink()
        iot.emit("log", "开始充电")
    else
        components.charge:turn_on()
        components.led_power:turn_on()
        iot.emit("log", "结束充电")
    end
end

-- 充电电流 1A 25mV，25倍放大
function battery.charge_current()
    if not battery.charging then
        return 0
    end

    local _, charge = iot.adc(1)
    local v = charge:get()
    charge:close()

    if v < 0 then
        return 0
    end

    local c = v / 625
    -- log.info("charge current: ", v, c, "A")
    return c
end

-- 放电电流 1A 5mV
function battery.usage_current()
    local _, charge = iot.adc(2)
    local v = charge:get()
    charge:close()

    if v < 0 then
        return 0
    end

    local c = v / 125
    return c
end

-- 实时电压 1/10分压
function battery.voltage()
    local _, voltage = iot.adc(0)
    local v = voltage:get()
    voltage:close()

    if v < 0 then
        return 0
    end

    local vbat = v / 100
    -- log.info("battery: ", v, vbat, "V")
    return vbat
end

local percent = 70

local function calc_battery()
    local battery_full = settings.device.battery_full or 28.5
    local battery_low = settings.device.battery_low or 23
    log.info("battery_full: ", battery_full, "battery_low: ", battery_low)

    local vbat = battery.voltage()
    local p = math.floor((vbat - battery_low) / (battery_full - battery_low) * 100)
    if p > 100 then
        p = 100
    elseif p < 0 then
        p = 0
    end

    log.info("calc: ", vbat, p, "%")

    return p
end

function battery.percent()
    if settings.device.battery_volume and settings.device.battery_volume > 0 then
        -- 使用AH计算
        return percent
    else
        -- 根据电压计算
        return calc_battery()
    end
end

local function battery_task()
    -- iot.sleep(5000)
    -- settings.device.battery_volume

    -- 电池容量，单位Ah，默认14Ah，换算成As
    local volume = (settings.device.battery_volume or 13) * 3600

    -- 根据电压计算的电量百分比，换算成当前电量，单位As
    local remain = volume * calc_battery() / 100

    while true do
        iot.sleep(1000)

        local battery_full = settings.device.battery_full or 28.5
        local battery_low = settings.device.battery_low or 23

        local vbat = battery.voltage()
        local charge_current = battery.charge_current()
        local usage_current = battery.usage_current()

        -- 状态灯
        if battery.charging then
            if charge_current < 0.4 and vbat < battery_full then
                components.led_power:turn_off() -- 充电故障
            else
                components.led_power:blink() -- 充电中
            end
        else
            components.led_power:turn_on() -- 未充电
        end

        -- 电压过低，认为电池没电了（避免误判）
        if vbat < battery_low and vbat > 3 then
            remain = 0
            goto continue
        end

        -- 电压过高，认为电池满了
        if vbat > battery_full and charge_current < 0.3 then
            remain = volume
            goto continue
        end

        -- 充电
        if battery.charging and charge_current > 0 then
            remain = remain + charge_current
        end

        -- 放电
        if usage_current > 0 then
            remain = remain - usage_current
        end

        ::continue::
        -- 计算电量百分比
        percent = math.floor(remain / volume * 100)
        if percent > 100 then
            percent = 100
        elseif percent < 0 then
            percent = 0
        end
    end
end

function battery.open()
    -- 默认打开电源灯
    components.led_power:turn_on()
    
    iot.start(battery_task)
end

battery.deps = {"components", "settings"}

-- 注册
boot.register("battery", battery)

return battery
