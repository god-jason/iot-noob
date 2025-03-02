local tag = "INPUT"

function init()
    for i, p in ipairs(INPUTS) do
        gpio.setup(p.pin, function(val)
            sys.publish("INPUT", i, val, p.pin)
            log.info(tag, "input", i, val, p.pin)
        end)
    end
end

function get(index)
    return gpio.get(INPUTS[index].pin)
end
