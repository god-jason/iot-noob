--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- 网卡相关
-- @module driver_lan
local lan = {}

local tag = "lan"

local configs = require("configs")

local default_options = {
    enable = false, -- 启用 (默认CORE不带驱动，需要重新编译固件)
    spi = 0,
    speed = 25600000,
    scs = 8,
    int = 1, -- EC618 1 EC718 29
    rst = 22 -- EC618 22 EC718 30
}

local options = {}

--- 以太网初始化
function lan.init()
    -- 加载配置
    options = configs.load_default(tag, default_options)
    if not options.enable then
        return
    end

    log.info(tag, "init")

    if netdrv ~= nil then

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
-- @return boolean
function lan.ready()
    if not options.enable then
        return false
    end

    if netdrv ~= nil then
        return netdrv.ready(socket.LWIP_ETH)
    else
        return false
    end

end

-- 启动
lan.init()

return lan
