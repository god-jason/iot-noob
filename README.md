# 物联小白

物联小白是基于Luatos实现的开源物联网网关系统，主要运行在合宙Air780系列模组上。因为是基于4G芯片二次开发，物联小白可以从最大程度上降低硬件成本。

市场上基于Air780e的4G DTU，比如：银尔达S710、DG720、D780等，都可以通过刷机物联小白程序变身智能网关。

物联小白是开源物联网平台[物联大师](https://github.com/god-jason/iot-master)的一部分，可以与之无缝结合。


# 主要功能和特点

- 支持物联大师MQTT协议标准
- 通过服务器远程配置
- ModbusRTU协议
- 电表DLT645协议
- 水表CJT188协议
- 主流PLC协议（串口）
- 定时休眠功能（可用于电池供电的场景）
- 支持以太网通讯
- 支持GPS定位功能
- ADC模拟量采集（需要使用 本易物联网的2-16通道RTU）
- 点位不限制，只要内存还够（Air780EPM模组内存较大）


## 开发进度
- [x] MQTT协议（上行，北向）
- [x] Modbus RTU
- [ ] Modbus ASCII（使用比较少，暂不做支持）
- [ ] 电表DLT645协议
- [ ] 水表CJT188协议
- [ ] 三菱PLC串口通讯协议
- [ ] 三菱PLC网口通讯协议
- [ ] 欧姆龙PLC串口通讯协议
- [ ] 欧姆龙PLC网口通讯协议
- [ ] 西门子PLC串口通讯协议
- [ ] 西门子PLC网口通讯协议

## 刷机说明

1. 下载Luatoos工具，[链接](https://wiki.luatos.com/pages/tools.html)
2. 双击更新，会自动下载相关库文件
3. 点击右上角“项目管理测试”
4. 创建一个名为noob的项目，然后“增加目录”，选择“Air780”目录
5. 选择底层CORE文件，一般是luatoos.exe同目录下，resource中对应模组的最新soc文件
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
