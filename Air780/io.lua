local tag = "IO"

local inputs = {27, 28, 29}
local outputs = {30, 31, 32}

function io_init()

    -- TODO 读取GPIO配置表

    for i, pin in ipairs(inputs) do
        gpio.setup(pin, function(val)
            sys.publish("IO_INPUT", i, val, pin)
            log.info(tag, "input", i, val, pin)
        end)
    end
end

function input_get(index)
    gpio.get(outputs[index])
end

function output_set(index, value)
    local pin = outputs[index]
    gpio.set(pin, value)
    log.info(tag, "output", index, value, pin)
end

