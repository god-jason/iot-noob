[![Lua Check](https://github.com/god-jason/iot-noob/actions/workflows/check.yml/badge.svg)](https://github.com/god-jason/iot-noob/actions/workflows/check.yml)
[![Lua Doc](https://github.com/god-jason/iot-noob/actions/workflows/doc.yml/badge.svg)](https://github.com/god-jason/iot-noob/actions/workflows/doc.yml)

# 物联小白

物联小白是基于 Luatos 实现的开源物联网网关系统，主要运行在合宙 Air780 系列模组上。因为是基于 4G 芯片二次开发，物联小白可以从最大程度上降低硬件成本。

市场上基于 Air780e 的 4G DTU，比如：银尔达 S710、DG720、D780 等，都可以通过刷机物联小白程序变身智能网关。

物联小白是开源物联网平台[物联大师](https://github.com/god-jason/iot-master)的一部分，可以与之无缝结合。

# 在线文档

[god-jason.github.io/iot-noob](https://god-jason.github.io/iot-noob)

## 定时器

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|定时| iot.setTimeout(func, timeout, ...) | 回调，超时ms，参数123 | id ||
|间隔定时| iot.setInterval(func, timeout, ...) | 回调，超时ms，参数123 | id ||
|清空定时| iot.clearTimeout(id) | 定时器ID | 无 ||
|清空间隔定时| iot.clearInterval(id) | 定时器ID | 无 ||

## 协程接口

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|启动协程| iot.start(func) | 回调 | 无 ||
|*停止协程| iot.stop(id) | 回调 | 无 | |
|休眠| iot.sleep(timeout) | 超时ms | 无 ||
|等待消息| iot.wait(topic, timeout) | 主题，超时 | 超时false，参数 ||

## 消息机制

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|订阅| iot.on(topic, func) | 主题，回调| 无 ||
|单次订阅| iot.once(topic, func) | 主题，回调| 无 ||
|取消订阅| iot.off(topic, func) | 主题，回调| 无 ||
|发布| iot.emit(topic, ...) | 主题，参数123| 无 ||

## 文件操作

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|打开文件| iot.open(filename, mode) | 文件名，参数 | 成功与否，文件对象 | 同LUA标准库，io.open |
|文件是否存在| iot.exists(filename) | 文件名 | 成功与否 ||
|读取文件内容| iot.readFile(filename) | 文件名 | 成功与否，文件内容 ||
|写入文件内容| iot.writeFile(filename, data) | 数据 | 成功与否 ||
|追加文件内容| iot.appendFile(filename, data) | 数据 | 成功与否 ||
|创建目录| iot.mkdir(path) | 路径 | 成功与否 ||
|删除目录| iot.rmdir(path) | 路径 | 成功与否 ||
|遍历目录| iot.walk(path, callback) | 路径，回调 | ||

## 加密算法

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|MD5| iot.md5(data) | 数据 | 加密结果 十六进制 ||
|HMAC MD5| iot.hmac_md5(data, key) | 数据，密钥 | 加密结果 十六进制 ||
|SHA1| iot.sha1(data) | 数据 | 加密结果 十六进制 ||
|HMAC SHA1| iot.hmac_sha1(data, key) | 数据，密钥 | 加密结果 十六进制 ||
|SHA256| iot.sha256(data) | 数据 | 加密结果 十六进制 ||
|HMAC SHA256| iot.hmac_sha256(data, key) | 数据，密钥 | 加密结果 十六进制 ||
|SHA512| iot.sha512(data) | 数据 | 加密结果 十六进制 ||
|HMAC SHA512| iot.hmac_sha512(data, key) | 数据，密钥 | 加密结果 十六进制||
|加密| iot.encrypt(type, padding, data, key, iv) | 类型，对齐，数据，密钥，IV | 加密结果 ||
|解密| iot.decrypt(type, padding, data, key, iv) | 类型，对齐，数据，密钥，IV | 解密结果 ||
|BASE64加密| iot.base64_encode(data) | 数据 | 加密结果 ||
|BASE64解密| iot.base64_decode(data) | 数据 | 解密结果 ||
|CRC8| iot.crc8(data)|数据|加密结果||
|CRC16| iot.crc16(type, data) | 数据 | 加密结果 | 类型 IBM MAXIM USB MODBUS CCITT CCITT-FALSE X25 XMODEM DNP USER-DEFINED|
|CRC32| iot.crc32(data)|数据|加密结果||

加密类型：
AES-128-ECB，AES-192-ECB，AES-256-ECB，AES-128-CBC，AES-192-CBC，AES-256-CBC，AES-128-CTR，AES-192-CTR，AES-256-CTR，AES-128-GCM，AES-192-GCM，AES-256-GCM，AES-128-CCM，AES-192-CCM，AES-256-CCM，DES-ECB，DES-EDE-ECB，DES-EDE3-ECB，DES-CBC，DES-EDE-CBC，DES-EDE3-CBC

对齐类型：
PKCS7，ZERO，ONE_AND_ZEROS，ZEROS_AND_LEN，NONE

## 其他接口

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|JSON编码| iot.json_encode(obj) | 对象 | 字符串，错误 | |
|JSON解码| iot.json_decode(str) | 字符串 | 对象，错误 | |
|PACK封包| iot.pack(fmt,...) | 格式，参数123 | 数据 | |
|PACK解包| iot.unpack(str，fmt, offset) | 字符串，格式，偏移 | 继续位置，解析值123 | |

```
PACK打包格式
 '<' 设为小端编码 
 '>' 设为大端编码 
 '=' 大小端遵循本地设置 
 'z' 空字符串,0字节
 'a' size_t字符串,前4字节表达长度,然后接着是N字节的数据
 'A' 指定长度字符串, 例如A8, 代表8字节的数据
 'f' float, 4字节
 'd' double , 8字节
 'n' Lua number , 32bit固件4字节, 64bit固件8字节
 'c' char , 1字节
 'b' byte = unsigned char  , 1字节
 'h' short  , 2字节
 'H' unsigned short  , 2字节
 'i' int  , 4字节
 'I' unsigned int , 4字节
 'l' long , 8字节, 仅64bit固件能正确获取
 'L' unsigned long , 8字节, 仅64bit固件能正确获取
 ```

## 网络接口

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|连接Socket服务器| iot.socket(options) | 参数 | 成功与否，对象 | options={host,port,is_udp,is_tls,...} |
|打开| socket:open() | 无 | 成功与否，错误信息 |  |
|关闭| socket:close() | 无 | 无 |  |
|读取| socket:read() | 无 | 成功与否，数据 |  |
|写入| socket:write(data) | 数据 | 成功与否，写入长度 |  |
|等待| socket:wait(timeout) | 超时 | 成功与否，缓存长度 |  |
|有效| socket:ready() | 无 | 是否有效 |  |

### HTTP协议

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|HTTP请求| iot.request(url, options) | URL，参数 | code,status,body | options={method, headers, body} |
|HTTP下载| iot.download(url, dst, options) | URL，目标路径，参数 | code,status,body | options={method, headers, body} |

### MQTT协议

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|连接MQTT服务器| iot.mqtt(options) | 参数 | 成功与否，对象 | options={host,port,clientid,username,password,ssl,...} |
|打开| mqtt:open() | 无 | 成功与否，错误信息 |  |
|关闭| mqtt:close() | 无 | 无 |  |
|发布消息| mqtt:publish(topic,payload,qos) | 主题，荷载，QOS | 成功与否，消息ID |  |
|订阅| mqtt:subscribe(filter, func) | 过滤器，回调 | 无 | 重复订阅不会互相影响 |
|取消订阅| mqtt:unsubscribe(filter, func) | 过滤器，回调 | 无 |  |
|有效| mqtt:ready() | 无 | 是否有效 |  |

ssl为true，表示简单的MQTTS

ssl为 {
    server_cert="服务器证书",
    client_cert="客户端证书",
    client_key="客户端秘钥",
    client_password="秘钥密码",
}

## 设备驱动

### GPIO

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|打开GPIO| iot.gpio(id, options) | ID，参数 | 成功与否，对象 | options={direct, pull，debounce, callback} |
|关闭GPIO| gpio:close() | 无 | 无 |  |
|设置GPIO| gpio:set(level) | 电平 | 无 |  |
|获取GPIO| gpio:get() | 无 | 电平 |  |

### UART

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|打开串口| iot.uart(id, options) | ID，参数 | 成功与否，流对象 | options={baud_rate, data_bits_bits, parity, bit_order, buffer_size, rs485_gpio, rs485_level, rs485_delay} |
|关闭| uart:close() | 无 | 无 |  |
|读取| uart:read() | 无 | 成功与否，数据 |  |
|写入| uart:write(data) | 数据 | 成功与否，写入长度 |  |
|等待| uart:wait(timeout) | 超时 | 成功与否，缓存长度 |  |

### I2C

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|打开i2c| iot.i2c(id, options) | ID，参数 | 成功与否，对象 | options={slow} |
|关闭| i2c:close() | 无 | 无 |  |
|读取| i2c:read(addr, len) | 地址，长度 | 成功与否，数据 |  |
|写入| i2c:write(addr, data) | 地址，数据 | 成功与否 |  |
|读寄存器| i2c:readRegister(addr, reg, len) | 地址，寄存口，长度 | 成功与否，数据|  |
|写寄存器| i2c:writeRegister(addr, reg, data) | 地址，寄存口，数据 | 成功与否 |  |

### SPI

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|打开spi| iot.spi(id, options) | ID，参数 | 成功与否，对象 | options={cs, CPHA, CPOL, data_bits, band_rate, bit_order, master, mode} |
|关闭| spi:close() | 无 | 无 |  |
|读取| spi:read(len) | 长度 | 成功与否，数据 |  |
|写入| spi:write(data) | 数据 | 成功与否 |  |
|询问| spi:ask(data) | 数据 | 成功与否，数据 |  |

### ADC

|功能|接口|参数|返回|说明|
|----|----|----|----|----|
|打开adc| iot.adc(id, options) | ID，参数 | 成功与否，对象 | options={} |
|关闭adc| adc:close() | 无 | 无 |  |
|读取adc| adc:get() | 无 | 电压 |  |

# 源码说明

- boot.lua 会遍历并自动加载所有脚本，所以请按需要下载程序
- luatos 源码最终是放在同一目录下的，不同目录下的文件也不能重名
- 此代码库并不依赖 luatools 的 lib 代码，所以需要取消“添加默认 lib”
- 需要勾选“忽略脚本依赖性”，否则会导致下载文件不全

| 目录      | 模块                     | 说明     |
| --------- | ------------------------ | -------- |
| core      | 核心代码                 | 全部下载 |
| links     | CAN、TCP、UDP 等连接代码 | 按需下载 |
| protocols | 各种协议代码             | 按需下载 |
| clouds    | 公共云平台适配代码       | 按需下载 |
| platforms | 平台适配                 | 目前仅支持LuatOS |
| test      | 测试代码                 |          |

## 开发进度

- [x] MQTT 协议（上行，北向）
- [x] Modbus RTU/TCP
- [ ] 电表 DLT645 协议
- [x] 水表 CJT188 协议
- [ ] 三菱 PLC 串口通讯协议
- [ ] 三菱 PLC 网口通讯协议
- [ ] 欧姆龙 PLC 串口通讯协议
- [ ] 欧姆龙 PLC 网口通讯协议
- [ ] 西门子 PLC 串口通讯协议
- [ ] 西门子 PLC 网口通讯协议

## 刷机说明

1. 下载 Luatoos 工具，[链接](https://luatos.com/luatools/download/last)
2. 打开软件，选择更新的库，下载相关库文件
3. 点击右上角“项目管理测试”
4. 创建一个名为 noob 的项目，然后“增加目录和文件”，选择adapters/luatos core links protocols等必要的目录和文件
5. 选择底层 CORE 文件，一般是 luatools.exe 同目录下，resource 中对应模组的最新 soc 文件
6. 点击下载底层和脚本（下载过底层之后就可以只选择下载脚本）

【后续可以出个录屏教程】

## 联系方式

南京本易物联网有限公司

- 邮箱：[jason@zgwit.com](mailto:jason@zgwit.com)
- 手机：[15161515197](tel:15161515197)(微信同号)

![微信](https://iot-master.com/jason.jpg)

## 开源协议

[GPL](https://github.com/zgwit/iot-noob/blob/main/LICENSE)

补充：产品仅限个人免费使用，商业需求请联系我们
