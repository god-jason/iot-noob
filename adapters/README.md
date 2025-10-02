# 系统适配层

主要用于适配合宙LuatOS以及其他Lua方案

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
|打开文件| iot.open(filename, mode) | 文件名，模式 | 成功与否，文件对象 | 同LUA标准库，io.open |
|文件是否存在| iot.exists(filename) | 文件名 | 成功与否 ||
|读取文件内容| iot.readFile(filename) | 文件名 | 成功与否，文件内容 ||
|写入文件内容| iot.writeFile(filename, data) | 数据 | 成功与否 ||
|追加文件内容| iot.appendFile(filename, data) | 数据 | 成功与否 ||

目录的操作

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

## 网络接口

## 蜂窝网络

## 设备驱动

### GPIO

### UART

### I2C

### SPI

### WiFi

### BLE

### NFC

### CAN
