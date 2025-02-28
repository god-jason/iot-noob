local tag = "OUTPUT"

local outputs = {30, 31, 32}

function set(index, value)
    local pin = outputs[index]
    gpio.set(pin, value)
    log.info(tag, "output", index, value, pin)
end

