local tag = "INPUT"

local input = {}

--- 初始化
function input.init()
    for i, p in ipairs(INPUTS) do
        gpio.setup(p.pin, function(val)
            sys.publish("INPUT", i, val, p.pin)
            log.info(tag, "input", i, val, p.pin)
        end)
    end
end

function input.get(index)
    return gpio.get(INPUTS[index].pin)
end

return input