--- 适配合宙的LuatOS
-- @module iot
local iot = {}

_G.sys = require("sys") -- 其实已经内置了
_G.iot = iot -- 注册到全局

-- 定时器
function iot.setTimeout(func, timeout, ...)
    return sys.timerStart(func, timeout, ...)
end
function iot.setInterval(func, timeout, ...)
    return sys.timerloopStart(func, timeout, ...)
end
function iot.clearTimeout(id)
    return sys.timerStop(id)
end
function iot.clearInterval(id)
    return sys.timerStop(id)
end

-- 协程管理
function iot.start(func, ...)
    -- TODO 这里返回是协程对象，不是线程ID
    return sys.taskInit(func, ...)
end
function iot.stop(id)
    return false
end
function iot.sleep(timeout)
    sys.wait(timeout)
end
function iot.wait(topic, timeout)
    return sys.waitUntil(topic, timeout)
end

-- 消息机制
function iot.on(topic, func)
    sys.subscribe(topic, func)
end
function iot.once(topic, func)
    local fn
    fn = function()
        func()
        sys.unsubscribe(topic, fn)
    end
    sys.subscribe(topic, fn)
end
function iot.off(topic, func)
    sys.unsubscribe(topic, func)
end
function iot.emit(topic, ...)
    sys.publish(topic, ...)
end

-- 文件系统
function iot.open(filename, mode)
    local fd = io.open(filename, mode)
    return fd ~= nil, fd
end
function iot.exists(filename)
    return io.exists(filename)
end
function iot.readFile(filename)
    local data = io.readFile(filename)
    return data ~= nil, data
end
function iot.writeFile(filename, data)
    return io.writeFile(filename, data)
end
function iot.appendFile(filename, data)
    return io.writeFile(filename, data, "ab+")
end
function iot.mkdir(path)
    return io.mkdir(path)
end
function iot.rmdir(path)
    return io.rmdir(path)
end
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

---- 加密模块
function iot.md5(data)
    return crypt.md5(data)
end
function iot.hmac_md5(data, key)
    return crypt.hmac_md5(data, key)
end
function iot.sha1(data)
    return crypt.sha1(data)
end
function iot.hmac_sha1(data, key)
    return crypt.hmac_sha1(data, key)
end
function iot.sha256(data)
    return crypt.sha256(data)
end
function iot.hmac_sha256(data, key)
    return crypt.hmac_sha256(data, key)
end
function iot.sha512(data)
    return crypt.sha512(data)
end
function iot.hmac_sha512(data, key)
    return crypt.hmac_sha512(data, key)
end
function iot.encrypt(type, padding, str, key, iv)
    return crypt.encrypt(type, padding, str, key, iv)
end
function iot.decrypt(type, padding, str, key, iv)
    return crypto.decrypt(type, padding, str, key, iv)
end
function iot.base64_encode(data)
    return crypto.base64_encode(data)
end
function iot.base64_decode(data)
    return crypto.base64_decode(data)
end
function iot.crc8(data)
    return crypto.crc8(data)
end
function iot.crc16(method, data)
    return crypto.crc16(method, data)
end
function iot.crc32(data)
    return crypto.crc32(data)
end

-- SOCKET
local Socket = require("socket.lua")
iot.socket = function(opts)
    return Socket:new(opts)
end

-- HTTP
function iot.request(url, opts)
    opts = opts or {}
    local method = opts.method or "GET"
    local headers = opts.headers or {}
    local body = opts.body
    return http.request(method, url, headers, body)
end
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
iot.mqtt = function(opts)
    return MqttClient:new(opts)
end

-- GPIO接口
local GPIO = {}
GPIO.__index = GPIO

function GPIO:close()
    gpio.close(self.id)
end
function GPIO:set(level)
    gpio.set(self.id, level)
end
function GPIO:get()
    return gpio.get(self.id)
end

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

-- 串口操作
local UART = {}
UART.__index = UART

function UART:close()
    uart.close(self.id)
end
function UART:write(data)
    local len = uart.write(self.id, data)
    return len > 0, len
end
function UART:read()
    local data = uart.read(self.id)
    return data ~= nil and #data > 0, data
end
function UART:wait(timeout)
    return sys.waitUntil("uart_receive_" .. self.id)
end

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

-- I2C
local I2C = {}
I2C.__index = I2C

function I2C:close()
    i2c.close(self.id)
end
function I2C:write(addr, data)
    return i2c.send(self.id, addr, data)
end
function I2C:read(addr, len)
    local data = i2c.read(self.id, addr, len)
    return data ~= nil and #data > 0, data
end
function I2C:writeRegister(addr, reg, data)
    return i2c.writeReg(self.id, addr, reg, data)
end
function I2C:readRegister(addr, reg, len)
    local data = i2c.readReg(self.id, addr, reg, len)
    return data ~= nil and #data > 0, data
end

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

-- SPI
local SPI = {}
SPI.__index = SPI

function SPI:close()
    self.dev:close()
end
function SPI:write(data)
    local len = self.dev:send(data)
    return len > 0
end
function SPI:read(len)
    local data = self.dev:read(len)
    return data ~= nil and #data > 0, data
end
function SPI:ask(data)
    local ret = self.dev:transfer(data)
    return ret ~= nil and #ret > 0, ret
end

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

-- ADC
local ADC = {}
ADC.__index = ADC

function ADC:close()
    adc.close(self.id)
end
function ADC:get()
    return adc.get(self.id)
end
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

-- 其他
function iot.json_encode(obj, ...)
    return json.encode(obj, ...)
end
function iot.json_decode(str)
    local obj, ret, err = json.decode(str)
    return obj, err
end
function iot.unpack(str, fmt, offset)
    return pack.unpack(str, fmt, offset)
end
function iot.pack(fmt, ...)
    return pack.pack(fmt, ...)
end

return iot
