-- 银尔达780系列 需要拉高 GPIO25，取消UART1输出屏蔽。。。
gpio.setup(25, 1, gpio.PULLUP)
