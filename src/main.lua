--- 主程序入口
--- @module main
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
PROJECT = "iot-noob"
VERSION = "1.0.0"

-- 测试
require("utils").walk("/")


--银尔达780系列 需要拉高 GPIO25，取消UART1输出屏蔽。。。
gpio.setup(25, 1, gpio.PULLUP)

-- 调用启动
require("boot")

sys.run()
