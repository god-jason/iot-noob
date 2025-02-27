local tag = "LAN"

-- PIN脚定义，要根据实际情况修改
local spi_id, spi_speed, pin_scs, pin_int, pin_rst = 0, 25600000, 8, 1, 22 --EC618
--local spi_id, spi_speed, pin_scs, pin_int, pin_rst = 0, 25600000, 8, 29, 30 --EC718
--local spi_id, spi_speed, pin_scs, pin_int, pin_rst = 2, 20000000, 6, 6, 8 --ESP32

function lan_init()

    if w5500 == nil then
        while 1 do
            log.info(tag, "当前固件未包含w5500库")
            --sys.wait(1000)
        end
    end

    -- 初始化SPI和5500
    w5500.init(spi_id, spi_speed, pin_scs, pin_int, pin_rst)

    -- 配置IP
    w5500.config() -- 默认是DHCP模式
    -- w5500.config("192.168.1.29", "255.255.255.0", "192.168.1.1") --静态IP模式
    -- w5500.config("192.168.1.122", "255.255.255.0", "192.168.1.1", string.fromHex("102a3b4c5d6e")) --mac地址

    w5500.bind(socket.ETH0)

end

-- sys.timerStart(lan_init, 100)

