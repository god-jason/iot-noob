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

--W5500芯片供电
gpio.setup(20, 1, gpio.PULLUP)

-- 调用启动
require("boot")


-- local relay = gpio.setup(2, 0)
-- local on = true
-- sys.timerLoopStart(function()
--     if on then
--         gpio.set(2, 0)
--         on = false
--     else
--         gpio.set(2, 1)
--         on = true
--     end
-- end, 1000)


sys.run()
