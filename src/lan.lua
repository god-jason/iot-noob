local tag = "LAN"

local lan = {
    w5500_ready = false
}

function lan.init()

    if not LAN.enable then
        return
    end

    if LAN.chip == "w5500" then

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

        lan.w5500_ready = true

    elseif LAN.chip == "ch390" then

        netdrv.setup(socket.LWIP_ETH)

        -- Air8000/Air780EPM初始化CH390H/D作为LAN口, 单一使用.不含WAN.
        netdrv.setup(socket.LWIP_ETH, netdrv.CH390, {
            spi = 0,
            cs = 8
        })
    
        -- 使用DHCP
        netdrv.dhcp(socket.LWIP_ETH, true)
        -- 配置固定IP
        -- netdrv.ipv4(id, addr, mark, gw)
    end

end

function lan.ready()
    if not LAN.enable then
        return false
    end
    
    if LAN.chip == "w5500" then
        return lan.w5500_ready --没有底层接口
    elseif LAN.chip == "ch390" then
        return netdrv.ready(socket.LWIP_ETH)
    else
        return false
    end

end

return lan
