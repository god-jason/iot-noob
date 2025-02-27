--- 物联小白，基于Air724模组实现的边缘计算网关，主要用于采集数据
-- @module main
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30

PROJECT = "iot-noob"
VERSION = "1.0.0"

require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE

require "sys"
require "net"

-- 每1分钟查询一次GSM信号强度,基站信息
-- net.startQueryAll(60000, 60000)

-- 此处关闭RNDIS网卡功能
ril.request("AT+RNDISCALL=0,1")

-- 加载网络指示灯和LTE指示灯功能模块
require "netLed"
pmd.ldoset(2, pmd.LDO_VLCD)
netLed.setup(true, pio.P0_1, pio.P0_4)

-- 加载远程升级功能模块
PRODUCT_KEY = "pgHEBKHLTryaYpYAaGDUOBncHYPR9m1l"
require "update"
update.request()


-- 加载网关程序
require "product"
require "noob"
require "rs485"


-- 启动系统框架
sys.init(0, 0)
sys.run()
