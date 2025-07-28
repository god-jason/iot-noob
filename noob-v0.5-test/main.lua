PROJECT = "noob-test"
VERSION = "0.0.1"

-- mcu.hardfault(2)

sys = require "sys"

-- 优先SIM0，然后SIM1
-- mobile.simid(2, true)

function testKey()

    local beep = gpio.setup(28, 0)

    -- 测试按键
    gpio.debounce(16, 300)
    gpio.setup(16, function(val)
        if val then
            log.info("key func")
        end
    end)

    gpio.debounce(17, 300)
    gpio.setup(17, function(val)
        if val then
            log.info("key menu")
        end
    end)

    gpio.debounce(3, 300)
    gpio.setup(3, function(val)
        if val then
            log.info("key up")
        end
    end)

    gpio.debounce(27, 300)
    gpio.setup(27, function(val)
        if val then
            log.info("key down")
        end
    end)

    gpio.debounce(24, 300)
    gpio.setup(24, function(val)
        if val then
            log.info("key enter")
        end
    end)

end

function testAudio()

    -- 测试音频
    local i2c_id = 0 -- i2c_id 0
    local pa_pin = gpio.AUDIOPA_EN -- 喇叭pa功放脚
    local power_pin = 20 -- es8311电源脚

    local i2s_id = 0 -- i2s_id 0
    local i2s_mode = 0 -- i2s模式 0 主机 1 从机
    local i2s_sample_rate = 16000 -- 采样率
    local i2s_bits_per_sample = 16 -- 数据位数
    local i2s_channel_format = i2s.MONO_R -- 声道, 0 左声道, 1 右声道, 2 立体声
    local i2s_communication_format = i2s.MODE_LSB -- 格式, 可选MODE_I2S, MODE_LSB, MODE_MSB
    local i2s_channel_bits = 16 -- 声道的BCLK数量

    local multimedia_id = 0 -- 音频通道 0
    local pa_on_level = 1 -- PA打开电平 1 高电平 0 低电平
    local power_delay = 3 -- 在DAC启动前插入的冗余时间，单位100ms
    local pa_delay = 100 -- 在DAC启动后，延迟多长时间打开PA，单位1ms
    local power_on_level = 1 -- 电源控制IO的电平，默认拉高
    local power_time_delay = 100 -- 音频播放完毕时，PA与DAC关闭的时间间隔，单位1ms

    local voice_vol = 60 -- 喇叭音量
    local mic_vol = 80 -- 麦克风音量

    gpio.setup(power_pin, 1, gpio.PULLUP) -- 设置ES83111电源脚
    gpio.setup(pa_pin, 1, gpio.PULLUP) -- 设置功放PA脚

    i2c.setup(i2c_id, i2c.FAST)
    i2s.setup(i2s_id, i2s_mode, i2s_sample_rate, i2s_bits_per_sample, i2s_channel_format, i2s_communication_format,
        i2s_channel_bits)

    audio.config(multimedia_id, pa_pin, pa_on_level, power_delay, pa_delay, power_pin, power_on_level, power_time_delay)
    audio.setBus(multimedia_id, audio.BUS_I2S, {
        chip = "es8311",
        i2cid = i2c_id,
        i2sid = i2s_id
    }) -- 通道0的硬件输出通道设置为I2S

    audio.vol(multimedia_id, voice_vol)
    audio.micVol(multimedia_id, mic_vol)

    audio.tts(0, "支付宝到账100万元")
end

-- 显示屏测试
function testOled()

    -- 初始化
    u8g2.begin({
        ic = "ssd1306",
        direction = 0,
        mode = "i2c_hw",
        i2c_id = 1
    })
    u8g2.ClearBuffer()
    u8g2.SendBuffer()

    -- 显示
    u8g2.SetFontMode(1)
    u8g2.ClearBuffer()
    -- u8g2.SetFont(u8g2.font_opposansm16_chinese)
    u8g2.SetFont(u8g2.font_opposansm12_chinese) -- 默认固件只有12号，巨丑无比
    u8g2.DrawUTF8("物联小白", 10, 12)
    u8g2.DrawUTF8("iot-noob", 10, 24)
    u8g2.DrawUTF8("zgwit.com", 10, 36)
    -- u8g2.drawGtfontUtf8("物联小白",32,0,0)
    u8g2.DrawUTF8("screen:" .. u8g2.GetDisplayWidth() .. " x " .. u8g2.GetDisplayHeight(), 10, 48)
    u8g2.SendBuffer()

end

function testLan()

    local result = spi.setup(
        0,--spi id
        nil,
        0,--CPHA
        0,--CPOL
        8,--数据宽度
        25600000--频率
        -- spi.MSB,--高低位顺序    可选，默认高位在前
        -- spi.master,--主模式     可选，默认主
        -- spi.full--全双工       可选，默认全双工
    )

    --netdrv.debug(0, true) -- 打开调试

    -- 创建netdrv, 使用CH390驱动, SPI0, 片选脚GPIO8
    netdrv.setup(socket.LWIP_ETH, netdrv.CH390, {
        spi = 0,
        spiid = 0,
        cs = 8
    })

    sys.wait(3000)

    netdrv.dhcp(socket.LWIP_ETH, true)

    
    sys.wait(10000)

    socket.sntp(nil, socket.LWIP_ETH) --测试网络

end

function testUart(id)
    log.info("testUart", id)
    -- uart.setup(id, 9600)	
    gpio.setup(22, 0, gpio.PULLDOWN)
    -- uart.setup(id, 9600, 8, 1, uart.NONE, uart.LSB, 1024, 22)
    uart.setup(id, 9600)
    uart.on(id, "receive", function(id, len)
        local data = uart.read(id, len)
        log.info("uart receive", id, len, data)
        -- uart.write(id, data) --on里面不能直接回复消息，会不会是rs485未翻转
        -- uart.write(id, "ack")
        sys.publish("UART_MSG_" .. id, data)
    end)
    uart.on(1, "sent", function(id, len)
        log.info(id, "sent", len)
    end)
    sys.timerLoopStart(function()
        log.info(id, "sent hello")
        uart.write(id, "hello")
    end, 5000)

    sys.subscribe("UART_MSG_" .. id, function(data)
        uart.write(id, "reply:" .. data)
    end)
end

local function can_cb(id, cb_type, param)
    if cb_type == can.CB_MSG then
        log.info("有新的消息")
        local succ, id, id_type, rtr, data = can.rx(id)
        while succ do
            log.info(mcu.x32(id), #data, data:toHex())
            succ, id, id_type, rtr, data = can.rx(id)
        end
    end
    if cb_type == can.CB_TX then
        if param then
            log.info("发送成功")
        else
            log.info("发送失败")
        end
    end
    if cb_type == can.CB_ERR then
        log.info("CAN错误码", mcu.x32(param))
    end
    if cb_type == can.CB_STATE then
        log.info("CAN新状态", param)
    end
end

function testCan()
	
	--beep用了can-stb
    --local beep = gpio.setup(28, 1)


	log.info("can mode:", can.MODE_NORMAL,can.MODE_LISTEN,can.MODE_TEST,can.MODE_SLEEP)
	log.info("can state:", can.STATE_STOP,can.STATE_ACTIVE,can.STATE_PASSIVE,
		can.STATE_BUSOFF,can.STATE_LISTEN,can.STATE_TEST,can.STATE_SLEEP)

	can.debug(true)

	local rx_id = 0x12345677
    local tx_id = 0x12345678

	local can_id = 0
    can.init(can_id, 128)
    can.on(can_id, can_cb)
    --can.timing(can_id, 1000000, 5, 4, 3, 2)
	--can.timing(can_id, 1000000, 6, 6, 4, 2)
	can.timing(can_id, 100000, 6, 6, 3, 2)
	--can.node(can_id, rx_id, can.EXT)
	--can.mode(can_id, can.MODE_NORMAL)
	can.mode(can_id, can.MODE_LISTEN)

	sys.timerLoopStart(function()
		can.tx(can_id, tx_id, can.EXT, false, true, "1234")
    end, 5000)
end

sys.taskInit(function()
    log.info("main")

    sys.wait(3000)

    -- testOled()

    testLan()

    -- testUart(0)
    -- testUart(1)
    -- testUart(2)

	testCan()

    while true do

        log.info("sleep")

        sys.wait(10000)

    end

end)

sys.run()
