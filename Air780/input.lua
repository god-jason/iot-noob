local tag = "INPUT"

local inputs = {27, 28, 29}

function init()

    -- TODO 读取GPIO配置表

    for i, pin in ipairs(inputs) do
        gpio.setup(pin, function(val)
            sys.publish("INPUT", i, val, pin)
            log.info(tag, "input", i, val, pin)
        end)
    end
end

function get(index)
    return gpio.get(outputs[index])
end
