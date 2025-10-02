--- 适配合宙的LuatOS
-- @module iot
local iot = {}

_G.sys = require("sys") -- 其实已经内置了
_G.iot = iot -- 注册到全局

--- 定时任务
-- @param func function 回调
-- @param timeout integer 超时
-- @return interger 定时器ID
function iot.setTimeout(func, timeout, ...)
    return sys.timerStart(func, timeout, ...)
end

--- 循环定时任务
-- @param func function 回调
-- @param timeout integer 超时
-- @return interger 定时器ID
function iot.setInterval(func, timeout, ...)
    return sys.timerLoopStart(func, timeout, ...)
end

--- 清空定时任务
-- @param id interger 定时器ID
function iot.clearTimeout(id)
    sys.timerStop(id)
end

--- 清空循环定时任务
-- @param id interger 定时器ID
function iot.clearInterval(id)
    sys.timerStop(id)
end

--- 创建协程
-- @param func function 回调
-- @param arg1 any 参数
-- @return interger 任务ID
function iot.start(func, ...)
    -- TODO 这里返回是协程对象，不是线程ID
    return sys.taskInit(func, ...)
end

--- 关闭协程
-- @param id interger 任务ID
function iot.stop(id)
    return false
end

--- 协程休眠
-- @param timeout integer 超时
function iot.sleep(timeout)
    sys.wait(timeout)
end

--- 等待消息，协程休眠
-- @param topic string 消息
-- @param timeout integer 超时
-- @return boolean 成功与否（超时false）
-- @return any 传参
function iot.wait(topic, timeout)
    return sys.waitUntil(topic, timeout)
end

--- 消息订阅
-- @param topic string 消息
-- @param func function 回调
function iot.on(topic, func)
    sys.subscribe(topic, func)
end

--- 消息订阅（单次）
-- @param topic string 消息
-- @param func function 回调
function iot.once(topic, func)
    local fn
    fn = function()
        func()
        sys.unsubscribe(topic, fn)
    end
    sys.subscribe(topic, fn)
end

--- 取消订阅
-- @param topic string 消息
-- @param func function 回调
function iot.off(topic, func)
    sys.unsubscribe(topic, func)
end

--- 发布消息
-- @param topic string 消息
-- @param arg1 any 参数
function iot.emit(topic, ...)
    sys.publish(topic, ...)
end

--- 打开文件
-- @param filename string 文件名
-- @param mode string 模式 r w a b + ...
-- @return boolean 成功与否
-- @return file 文件对象，通过file:read file:write file:seek file:close操作
function iot.open(filename, mode)
    local fd = io.open(filename, mode)
    return fd ~= nil, fd
end

--- 文件是否存在
-- @param filename string 文件名
-- @return boolean 成功与否
function iot.exists(filename)
    return io.exists(filename)
end

--- 读取文件全部内容
-- @param filename string 文件名
-- @return boolean 成功与否
-- @return string 内容
function iot.readFile(filename)
    local data = io.readFile(filename)
    return data ~= nil, data
end

--- 写入文件内容（覆盖）
-- @param filename string 文件名
-- @param data string 数据
-- @return boolean 成功与否
function iot.writeFile(filename, data)
    return io.writeFile(filename, data)
end

--- 写入文件内容（追加）
-- @param filename string 文件名
-- @param data string 数据
-- @return boolean 成功与否
function iot.appendFile(filename, data)
    return io.writeFile(filename, data, "ab+")
end

--- 创建目录
-- @param path string 文件名
-- @return boolean 成功与否
function iot.mkdir(path)
    return io.mkdir(path)
end

--- 创建目录
-- @param path string 文件名
-- @return boolean 成功与否
function iot.rmdir(path)
    return io.rmdir(path)
end

--- 遍历目录
-- @param path string 文件名
-- @param cb function(filename) 回调
-- @param offset integer 跳过
function iot.walk(path, cb, offset)
    offset = offset or 0

    local ret, data = io.lsdir(path, 50, offset)
    if not ret then
        return
    end
    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            -- 遍历子目录
            io.walk(fn .. "/", cb)
        else
            cb(fn)
        end
    end
    -- 继续遍历
    if #data == 50 then
        io.walk(path, cb, offset + 50)
    end
end

--- MD5加密
-- @param data string 数据
-- @return string 加密后的十六进制串
function iot.md5(data)
    return crypt.md5(data)
end
--- HMAC MD5加密
-- @param data string 数据
-- @param key string 秘钥
-- @return string 加密后的十六进制串
function iot.hmac_md5(data, key)
    return crypt.hmac_md5(data, key)
end
--- SHA1加密
-- @param data string 数据
-- @return string 加密后的十六进制串
function iot.sha1(data)
    return crypt.sha1(data)
end
--- HMAC SHA1加密
-- @param data string 数据
-- @param key string 秘钥
-- @return string 加密后的十六进制串
function iot.hmac_sha1(data, key)
    return crypt.hmac_sha1(data, key)
end
--- SHA256加密
-- @param data string 数据
-- @return string 加密后的十六进制串
function iot.sha256(data)
    return crypt.sha256(data)
end
--- HMAC SHA256加密
-- @param data string 数据
-- @param key string 秘钥
-- @return string 加密后的十六进制串
function iot.hmac_sha256(data, key)
    return crypt.hmac_sha256(data, key)
end
--- SHA512加密
-- @param data string 数据
-- @return string 加密后的十六进制串
function iot.sha512(data)
    return crypt.sha512(data)
end
--- HMAC SHA512加密
-- @param data string 数据
-- @param key string 秘钥
-- @return string 加密后的十六进制串
function iot.hmac_sha512(data, key)
    return crypt.hmac_sha512(data, key)
end

--- 加密
-- @param type string 类型 AES-128-ECB，AES-192-ECB，AES-256-ECB，AES-128-CBC，
-- AES-192-CBC，AES-256-CBC，AES-128-CTR，AES-192-CTR，AES-256-CTR，AES-128-GCM，
-- AES-192-GCM，AES-256-GCM，AES-128-CCM，AES-192-CCM，AES-256-CCM，DES-ECB，
-- DES-EDE-ECB，DES-EDE3-ECB，DES-CBC，DES-EDE-CBC，DES-EDE3-CBC
-- @param padding string 对齐 PKCS7，ZERO，ONE_AND_ZEROS，ZEROS_AND_LEN，NONE
-- @param str string 明文
-- @param key string 秘钥
-- @param iv string IV
-- @return string 密文
function iot.encrypt(type, padding, str, key, iv)
    return crypt.encrypt(type, padding, str, key, iv)
end

--- 解密
-- @param type string 类型
-- @param padding string 对齐
-- @param str string 密文
-- @param key string 秘钥
-- @param iv string IV
-- @return string 明文
function iot.decrypt(type, padding, str, key, iv)
    return crypto.decrypt(type, padding, str, key, iv)
end
--- BASE64编码
-- @param data string 数据
-- @return string base64编码
function iot.base64_encode(data)
    return crypto.base64_encode(data)
end
--- BASE64解码
-- @param data string base64编码
-- @return string 数据
function iot.base64_decode(data)
    return crypto.base64_decode(data)
end
--- CRC8校验
-- @param data string 数据
-- @return integer 检验
function iot.crc8(data)
    return crypto.crc8(data)
end
--- CRC16校验
-- @param method string 类型 IBM MAXIM USB MODBUS CCITT CCITT-FALSE X25 XMODEM DNP USER-DEFINED
-- @param data string 数据
-- @return integer 检验
function iot.crc16(method, data)
    return crypto.crc16(method, data)
end
--- CRC32校验
-- @param data string 数据
-- @return integer 检验
function iot.crc32(data)
    return crypto.crc32(data)
end

--- JSON编码
-- @param obj table 对象
-- @return string 文本
-- @return string error
function iot.json_encode(obj, ...)
    return json.encode(obj, ...)
end
--- JSON解码
-- @param str string 文本
-- @return table 对象
-- @return string error
function iot.json_decode(str)
    local obj, ret, err = json.decode(str)
    return obj, err
end
--- PACK打包
-- @param fmt string 格式
-- @param arg1 any 参数
-- @return string 文本
function iot.pack(fmt, ...)
    return pack.pack(fmt, ...)
end
--- PACK解包
-- @param str string 格式
-- @param fmt string 格式
-- @param offset integer 偏移
-- @return integer 下个字符
-- @return any 值1-n
function iot.unpack(str, fmt, offset)
    return pack.unpack(str, fmt, offset)
end

--- 重启
function iot.reboot()
    rtos.reboot()
end

local Socket = require("socket.lua")

--- 创建SOCKET
-- @param opts
-- @return Socket
function iot.socket(opts)
    return Socket:new(opts)
end

--- HTTP请求
-- @param url string URL
-- @param opts table 参数 {method, headers, body}
-- @return integer status
-- @return table headers
-- @return string body
function iot.request(url, opts)
    opts = opts or {}
    local method = opts.method or "GET"
    local headers = opts.headers or {}
    local body = opts.body
    return http.request(method, url, headers, body)
end
--- HTTP下载
-- @param url string URL
-- @param dst string 目标路径
-- @param opts table 参数 {method, headers, body}
-- @return integer status
-- @return table headers
-- @return string body
function iot.download(url, dst, opts)
    opts = opts or {}
    local method = opts.method or "GET"
    local headers = opts.headers or {}
    local body = opts.body
    local options = {
        dst = dst -- 下载文件
    }
    return http.request(method, url, headers, body)
end

-- MQTT
local MqttClient = require("mqtt_client.lua")

--- 创建MQTT
-- @param opts table
-- @return MqttClient
function iot.mqtt(opts)
    return MqttClient:new(opts)
end

--- GPIO接口
-- @module gpio
local GPIO = {}
GPIO.__index = GPIO

--- 关闭
function GPIO:close()
    gpio.close(self.id)
end
--- 设置电平
-- @return level integer
function GPIO:set(level)
    gpio.set(self.id, level)
end
--- 获取电平
-- @return integer level
function GPIO:get()
    return gpio.get(self.id)
end

--- 创建GPIO对象
-- @param id integer GPIO序号
-- @param opts table 参数 {pull, callback, debounce}
-- @return boolean 成功与否
-- @return GPIO
function iot.gpio(id, opts)
    opts = opts or {}
    local pull = opts.pull and gpio.PULLUP or gpio.PULLDOWN

    if opts.callback == nil then
        -- 输出模式
        gpio.setup(id, 0, pull)
    else
        -- 输入模式
        gpio.set(id, opts.callback, pull)
        if opts.debounce then
            gpio.debounce(id, opts.debounce)
        end
    end

    -- 返回对象实例
    return true, setmetatable({
        id = id
    }, GPIO)
end

--- 串口操作
-- @module uart
local UART = {}
UART.__index = UART

--- 关闭
function UART:close()
    uart.close(self.id)
end
--- 写入
-- @param data string 数据
-- @return boolean 成功与否
function UART:write(data)
    local len = uart.write(self.id, data)
    return len > 0, len
end
--- 读取
-- @return boolean 成功与否
-- @return string 数据
function UART:read()
    local data = uart.read(self.id)
    return data ~= nil and #data > 0, data
end
--- 等待
-- @param timeout integer 超时
-- @return boolean 成功与否
-- @return interger 数据长度
function UART:wait(timeout)
    return sys.waitUntil("uart_receive_" .. self.id)
end

--- 创建UART对象
-- @param id integer
-- @param opts table 参数 {band_rate, data_bits, stop_bits, parity, rs485_gpio, rs485_level, rs485_delay}
-- @return boolean 成功与否
-- @return UART
function iot.uart(id, opts)
    opts = opts or {}

    local baud_rate = opts.baud_rate or 9600
    local data_bits = opts.data_bits or 8
    local stop_bits = opts.stop_bits or 1
    local partiy = uart.None
    if opts.parity == 'N' or opts.parity == 'n' then
        partiy = uart.None
    elseif opts.parity == 'E' or opts.parity == 'e' then
        partiy = uart.Even
    elseif opts.parity == 'O' or opts.parity == 'o' then
        partiy = uart.Odd
    end
    local bit_order = opts.bit_order or uart.LSB -- 默认小端
    local buff_size = opts.buff_size or 1024
    local rs485_gpio = opts.rs485_gpio or 0xffffffff
    local rs485_level = opts.rs485_level or 0
    local rs485_delay = opts.rs485_delay or 20000

    local ret = uart.setup(id, baud_rate, data_bits, stop_bits, partiy, bit_order, buff_size, rs485_gpio, rs485_level,
        rs485_delay)
    if ret ~= 0 then
        return false, "打开失败"
    end

    uart.on(id, "receive", function(id2, len)
        sys.publish("uart_receive_" .. id2, len)
    end)

    -- 返回对象实例
    return true, setmetatable({
        id = id
    }, UART)
end

--- I2C
-- @module i2c
local I2C = {}
I2C.__index = I2C

--- 关闭
function I2C:close()
    i2c.close(self.id)
end
--- 写入
-- @param addr integer 从站号
-- @param data string 数据
-- @return boolean 成功与否
function I2C:write(addr, data)
    return i2c.send(self.id, addr, data)
end
--- 读取
-- @param addr integer 从站号
-- @param len integer 数据长度
-- @return boolean 成功与否
-- @return string 数据
function I2C:read(addr, len)
    local data = i2c.read(self.id, addr, len)
    return data ~= nil and #data > 0, data
end
--- 写入寄存器
-- @param addr integer 从站号
-- @param reg integer 寄存器
-- @param data string 数据
-- @return boolean 成功与否
function I2C:writeRegister(addr, reg, data)
    return i2c.writeReg(self.id, addr, reg, data)
end
--- 读取寄存器
-- @param addr integer 从站号
-- @param reg integer 寄存器
-- @param len integer 长度
-- @return boolean 成功与否
-- @return string 数据
function I2C:readRegister(addr, reg, len)
    local data = i2c.readReg(self.id, addr, reg, len)
    return data ~= nil and #data > 0, data
end

--- 创建I2C对象
-- @param id integer
-- @param opts table 参数 {slow=false}
-- @return boolean 成功与否
-- @return I2C
function iot.i2c(id, opts)
    opts = opts or {}

    local ret = i2c.setup(id, opts.slow and i2c.SLOW or i2c.FAST)
    if ret ~= 1 then
        return false, "打开失败"
    end
    -- 返回对象实例
    return true, setmetatable({
        id = id
    }, I2C)
end

--- SPI
-- @module spi
local SPI = {}
SPI.__index = SPI
--- 关闭
function SPI:close()
    self.dev:close()
end
--- 写入
-- @param data string 数据
-- @return boolean 成功与否
function SPI:write(data)
    local len = self.dev:send(data)
    return len > 0
end
--- 读取
-- @param len integer 长度
-- @return boolean 成功与否
-- @return string 数据
function SPI:read(len)
    local data = self.dev:read(len)
    return data ~= nil and #data > 0, data
end
--- 问询
-- @param data string 数据
-- @return boolean 成功与否
-- @return string 数据
function SPI:ask(data)
    local ret = self.dev:transfer(data)
    return ret ~= nil and #ret > 0, ret
end

--- 创建SPI对象
-- @param id integer
-- @param opts table 参数 {cs, CPHA, CPOL, band_rate, data_bits, master, mode}
-- @return boolean 成功与否
-- @return SPI
function iot.spi(id, opts)
    opts = opts or {}
    local cs = opts.cs or 0
    local CPHA = opts.CPHA or 0
    local CPOL = opts.CPOL or 0
    local dataw = opts.data_bits or 8
    local bandrate = opts.band_rate or 20000000 -- 默认20M
    local bitdict = opts.bit_order or spi.MSB -- 默认大端
    local ms = opts.master and 1 or 0
    local mode = opts.mode or 1

    local dev = spi.deviceSetup(id, cs, CPHA, CPOL, dataw, bandrate, bitdict, ms, mode)
    if dev == nil then
        return false, "打开失败"
    end
    -- 返回对象实例
    return true, setmetatable({
        dev = dev
    }, SPI)
end

--- ADC
-- @module adc
local ADC = {}
ADC.__index = ADC
--- 关闭
function ADC:close()
    adc.close(self.id)
end
--- 获取电压
-- @return integer 电压
function ADC:get()
    return adc.get(self.id)
end

--- 创建ADC对象
-- @param id integer
-- @param opts table 参数 {}
-- @return boolean 成功与否
-- @return ADC
function iot.adc(id, opts)
    opts = opts or {}
    local ret = adc.open(id)
    if not ret then
        return false, "打开失败"
    end
    return true, setmetatable({
        id = id
    }, ADC)
end



--- PWM
-- @module pwm
local PWM = {}
PWM.__index = PWM
--- 启动
-- @return boolean 成功与否
function PWM:start()
    return pwm.start(self.id)
end
--- 停止
-- @return boolean 成功与否
function PWM:stop()
    return pwm.stop(self.id)
end
--- 设置频率
-- @param freq integer 频率
-- @return boolean 成功与否
function PWM:setFreq(freq)
    return pwm.setFreq(self.id, freq)
end
--- 设置占空比
-- @param duty integer 占空比 %
-- @return boolean 成功与否
function PWM:setDuty(duty)
    return pwm.setDuty(self.id, duty)
end


--- 创建PWM对象
-- @param id integer
-- @param opts table 参数 {}
-- @return boolean 成功与否
-- @return PWM
function iot.pwm(id, opts)
    opts = opts or {}
    local ret = pwm.setup(id, opts.freq, opts.duty)
    if not ret then
        return false, "打开失败"
    end
    return true, setmetatable({
        id = id
    }, PWM)
end





return iot
