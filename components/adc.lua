--- ADC组件封装
-- @module adc
local ADC = require("utils").class(require("component"))

require("components").register("adc", ADC)

local filters = require("filters")

local log = iot.logger("adc")

function ADC:init()
    self.id = self.id -- 通道ID
    self.interval = self.interval or 1000 -- 采集间隔
    self.filter_name = "ma"
    self.filter_options = {
        size = 10
    }
    self.value = nil
    self.timer = nil
end

--- 初始化ADC硬件
function ADC:open()
    local ret, adc = iot.adc(self.id)
    if not ret then
        return false, adc
    end
    self.adc = adc
    if self.interval > 0 then
        if self.timer then
            iot.clearInterval(self.timer)
        end

        self.timer = iot.setInterval(function()
            self:read()
        end, self.interval)
    end

    if self.filter_name then
        self.filter = filters.create(self.filter_name, self.filter_options)
    end

    return true
end

--- 读取
function ADC:read()
    -- 读取ADC
    local val = self.adc:get()
    if not val then
        return 0
    end

    -- 滤波
    if self.filter then
        self.value = self.filter:update(val)
    else
        self.value = val
    end

    return self.value
end

--- 停止采样
function ADC:stop()
    if self.timer then
        iot.clearInterval(self.timer)
        self.timer = nil
    end
    self.adc:close()
end

--- 设置值
function ADC:set(key, value)
    if key == "read" then
        self:read()
    else
        return false, "ADC组件不支持变量：" .. key
    end
    return true
end

function ADC:get(key)
    if key == "value" then
        return true, self.value
    else
        return false, "ADC组件不支持变量：" .. key
    end
end

return ADC
