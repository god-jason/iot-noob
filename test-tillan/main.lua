PROJECT = "noob-tillan"
VERSION = "000.000.005"

log.info(PROJECT, VERSION)

PRODUCT_KEY = "lvrZyi3ESNW7Y5NMRuvMJWPkepdeY4pM"

mcu.hardfault(2)

sys = require "sys"

-- 优先SIM0，然后SIM1
mobile.simid(2, true)

function testLcd()
    lcd.init("st7789", {
        port = lcd.HWID_0,
        pin_dc = 0xff, -- 38, -- 0xff, -- RS
        pin_pwr = 23, -- BL 25,
        pin_rst = 36, -- RES
        direction = 0,
        w = 240,
        h = 320
    }, lcd.HWID_0)

    lcd.on()

    lcd.setupBuff(nil, true)
    lcd.autoFlush(false)

    lcd.clear()
    lcd.showImage(0, 10, "/luadb/logo.jpg")
    lcd.showImage(0, 90, "/luadb/tillan.jpg")

    lcd.flush()
end

sys.taskInit(function()
    log.info("main")

    sys.wait(1000)

    -- testLcd()

    require("cloud").init()

    require("tillan").init()

    require("ota") -- OTA升级

end)

sys.run()
