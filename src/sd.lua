local tag = "TAG"
local sd  = {}

function sd.init()
    if not SD.enable then
        return false
    end

    spi.setup(SD.spi, 255, 0, 0, 8, 4000000)

    gpio.setup(SD.cs_pin, 1)
    -- fatfs.debug(1)

    fatfas.mount(fatfs.SPI, "SD", SD.spi, SD.cs_pin, SD.speed)
end

return sd