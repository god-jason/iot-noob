local tag = "LAN"

function lan_init()

    if w5500 == nil then
        while 1 do
            log.info(tag, "当前固件未包含w5500库")
            sys.wait(1000)
        end
    end

    if rtos_bsp:startsWith("ESP32") then
        -- ESP32C3, GPIO5接SCS, GPIO6接IRQ/INT, GPIO8接RST
        w5500.init(2, 20000000, 5, 6, 8)
    elseif rtos_bsp:startsWith("EC618") then
        -- EC618系列, 如Air780E/Air600E/Air700E
        -- GPIO8接SCS, GPIO1接IRQ/INT, GPIO22接RST
        w5500.init(0, 25600000, 8, 1, 22)
    elseif rtos_bsp:startsWith("EC718") then
        -- EC718P系列, 如Air780EP/Air780EPV
        -- GPIO8接SCS, GPIO29接IRQ/INT, GPIO30接RST
        w5500.init(0, 25600000, 8, 29, 30)
    end

    w5500.config() -- 默认是DHCP模式
    -- w5500.config("192.168.1.29", "255.255.255.0", "192.168.1.1") --静态IP模式
    -- w5500.config("192.168.1.122", "255.255.255.0", "192.168.1.1", string.fromHex("102a3b4c5d6e")) --mac地址

    w5500.bind(socket.ETH0)

end

sys.timerStart(lan_init, 100)

