-- 银尔达700系列 需要拉高 GPIO20，取消UART1输出屏蔽。。。
gpio.setup(20, 1, gpio.PULLUP)
