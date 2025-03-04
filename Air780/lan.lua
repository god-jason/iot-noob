local tag = "LAN"

local lan = {}

function lan.init()

    if not LAN.enable then
        return
    end

    if w5500 == nil then
        while 1 do
            log.info(tag, "当前固件未包含w5500库")
            sys.wait(1000)
        end
    end

    -- 初始化SPI和5500
    w5500.init(LAN.spi, LAN.speed, LAN.scs, LAN.int, LAN.rst)

    -- 配置IP
    w5500.config() -- 默认是DHCP模式
    -- w5500.config("192.168.1.29", "255.255.255.0", "192.168.1.1") --静态IP模式
    -- w5500.config("192.168.1.122", "255.255.255.0", "192.168.1.1", string.fromHex("102a3b4c5d6e")) --mac地址

    w5500.bind(socket.ETH0)

end

return lan