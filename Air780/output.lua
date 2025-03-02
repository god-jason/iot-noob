local tag = "OUTPUT"

function set(index, value)
    local p = OUTPUTS[index]
    gpio.set(p.pin, value)
    log.info(tag, "output", index, value, p.pin)
end

