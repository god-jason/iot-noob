--- 网卡相关
--- @module "lan"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "lan"

local lan = {}

local configs = require("configs")

local default_options = {
    enable = false, -- 启用 (默认CORE不带驱动，需要重新编译固件)
    chip = "w5500", -- 型号 w5500 ch390
    spi = 0,
    speed = 25600000,
    scs = 8,
    int = 1, -- EC618 1 EC718 29
    rst = 22 -- EC618 22 EC718 30
}

local options = {}

--- 以太网初始化
function lan.init()

    log.info(tag, "init")

    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    if options.chip == "w5500" then

        if w5500 == nil then
            log.error(tag, "当前固件未包含w5500库")
            return
        end

        -- 初始化SPI和5500
        w5500.init(options.spi, options.speed, options.scs, options.int, options.rst)

        -- 配置IP
        w5500.config() -- 默认是DHCP模式
        -- w5500.config("192.168.1.29", "255.255.255.0", "192.168.1.1") --静态IP模式
        -- w5500.config("192.168.1.122", "255.255.255.0", "192.168.1.1", string.fromHex("102a3b4c5d6e")) --mac地址

        w5500.bind(socket.ETH0)
        -- lan.w5500_ready = true
    elseif options.chip == "ch390" then

        netdrv.setup(socket.LWIP_ETH)

        -- Air8000/Air780EPM初始化CH390H/D作为config口, 单一使用.不含WAN.
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

-- 以太网是否可用
--- @return boolean
function lan.ready()
    if not options.enable then
        return false
    end

    if options.chip == "w5500" then
        -- return lan.w5500_ready --没有底层接口
        return true
    elseif options.chip == "ch390" then
        return netdrv.ready(socket.LWIP_ETH)
    else
        return false
    end

end

-- 启动
lan.init()

return lan
