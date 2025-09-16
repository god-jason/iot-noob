[![Lua Check](https://github.com/god-jason/iot-noob/actions/workflows/check.yml/badge.svg)](https://github.com/god-jason/iot-noob/actions/workflows/check.yml)
[![Lua Doc](https://github.com/god-jason/iot-noob/actions/workflows/doc.yml/badge.svg)](https://github.com/god-jason/iot-noob/actions/workflows/doc.yml)


# 物联小白

物联小白是基于 Luatos 实现的开源物联网网关系统，主要运行在合宙 Air780 系列模组上。因为是基于 4G 芯片二次开发，物联小白可以从最大程度上降低硬件成本。

市场上基于 Air780e 的 4G DTU，比如：银尔达 S710、DG720、D780 等，都可以通过刷机物联小白程序变身智能网关。

物联小白是开源物联网平台[物联大师](https://github.com/god-jason/iot-master)的一部分，可以与之无缝结合。

![alt](https://image.lceda.cn/pullimage/BBpgLdzxAeu0cEkItb8gZoAhCBcdp3c8SK4OoKvZ.png)

[嘉立创开源地址https://oshwhub.com/zgwit/iot-noob](https://oshwhub.com/zgwit/iot-noob)

# 使用文档

[god-jason.github.io/iot-noob](https://god-jason.github.io/iot-noob)


# 主要功能和特点

-   支持物联大师 MQTT 协议标准
-   通过服务器远程配置
-   ModbusRTU 协议
-   电表 DLT645 协议
-   水表 CJT188 协议
-   主流 PLC 协议（串口）
-   支持定时任务，可做定时控制
-   定时休眠功能（可用于电池供电的场景）
-   支持以太网通讯
-   支持 GPS 定位功能
-   ADC 模拟量采集（需要使用 本易物联网的 2-16 通道 RTU）
-   点位不限制，只要内存还够（Air780EPM、Air8000 模组的内存较大）

# 源码说明

-   boot.lua 会遍历并自动加载所有脚本，所以请按需要下载程序
-   luatos 源码最终是放在同一目录下的，不同目录下的文件也不能重名
-   此代码库并不依赖 luatools 的 lib 代码，所以需要取消“添加默认 lib”，并勾选“忽略脚本依赖性”

| 目录      | 模块                     | 说明     |
| --------- | ------------------------ | -------- |
| boards    | PCB 适配                 |          |
| clouds    | 公共云平台适配代码       | 按需下载 |
| core      | 核心代码                 | 全部下载 |
| drivers   | 驱动代码                 | 按需下载 |
| links     | CAN、TCP、UDP 等连接代码 | 按需下载 |
| protocols | 各种协议代码             | 按需下载 |
| test      | 测试代码                 |          |

## 开发进度

-   [x] MQTT 协议（上行，北向）
-   [x] Modbus RTU
-   [ ] Modbus ASCII（使用比较少，暂不做支持）
-   [ ] 电表 DLT645 协议
-   [ ] 水表 CJT188 协议
-   [ ] 三菱 PLC 串口通讯协议
-   [ ] 三菱 PLC 网口通讯协议
-   [ ] 欧姆龙 PLC 串口通讯协议
-   [ ] 欧姆龙 PLC 网口通讯协议
-   [ ] 西门子 PLC 串口通讯协议
-   [ ] 西门子 PLC 网口通讯协议

## 刷机说明

1. 下载 Luatoos 工具，[链接](https://wiki.luatos.com/pages/tools.html)
2. 双击更新，会自动下载相关库文件
3. 点击右上角“项目管理测试”
4. 创建一个名为 noob 的项目，然后“增加目录”，选择“Air780”目录
5. 选择底层 CORE 文件，一般是 luatoos.exe 同目录下，resource 中对应模组的最新 soc 文件
6. 点击下载底层和脚本（下载过底层之后就可以只选择下载脚本）

【后续可以出个录屏教程】

## 联系方式

南京本易物联网有限公司

-   邮箱：[jason@zgwit.com](mailto:jason@zgwit.com)
-   手机：[15161515197](tel:15161515197)(微信同号)

![微信](https://iot-master.com/jason.jpg)

## 开源协议

[GPL](https://github.com/zgwit/iot-noob/blob/main/LICENSE)

补充：产品仅限个人免费使用，商业需求请联系我们
