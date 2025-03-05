local tag = "OUTPUT"
local output = {}

function output.set(index, value)
    local p = OUTPUTS[index]
    gpio.set(p.pin, value)
    log.info(tag, "output", index, value, p.pin)
end

return output