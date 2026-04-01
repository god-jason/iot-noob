[![Lua Check](https://github.com/god-jason/iot-os/actions/workflows/check.yml/badge.svg)](https://github.com/god-jason/iot-os/actions/workflows/check.yml)
[![Lua Doc](https://github.com/god-jason/iot-os/actions/workflows/doc.yml/badge.svg)](https://github.com/god-jason/iot-os/actions/workflows/doc.yml)

# 物联小白

物联小白是基于 Luatos 实现的开源物联网网关和机器人系统，主要运行在合宙 Air780 系列模组上。因为是基于 4G 芯片二次开发，物联小白可以从最大程度上降低硬件成本。

市场上基于 Air780EPM 的 4G DTU，比如：银尔达 S710、DG720、D780 等，都可以通过刷机物联小白程序变身智能网关。

物联小白是开源物联网平台[物联大师](https://github.com/god-jason/iot-master)的一部分，可以与之无缝结合。

二次开发在线文档 [god-jason.github.io/iot-noob](https://god-jason.github.io/iot-noob)

# 一、软件功能和特点

- 自动加载，程序按需引入
- 类定义，继承链，utils.class(parent)
- 事件机制，on once emit cancel
- 配置文件管理
- 简易数据库（与服务器同步用）
- crontab计划任务
- 物模型
- 数据点解析和编码（协议库用）
- 连接管理，串口管理
- Request数据请求封装，异步变阻塞调用（协议库用）
- 设备管理，主设备，子设备，虚拟设备
- 云平台数据上报，远程控制
- 陶晶驰串口屏

## 1 网关框架


### 1.1 基础协议库

- Modbus RTU/TCP
- CJT188（需要MBus总线）
- DLT645
- 更多协议需要慢慢来~

### 1.2 内联设备

将外置设备，比如传感器、流量计、开关等集成网关上，作为一个完整的单一设备上传到云平台

### 1.3 智能场景

类似智能家居App的智能场景，满足对应状态和条件之后，执行对应的动作，比如：当液位下降到1米时，水泵停止工作。
对于简单自动控制逻辑的设备，直接使用智能场景即可满足。

__“内联设备”和“智能场景”这两个功能对于开发者十分有用，无需开发PCB和程序，直接拿物联小白，通过485连接需要的传感器和控制器，即可形成专用的产品__

## 2、机器人框架

### 2.1 组件库

- ADC 模拟量采集
- LED 指示灯
- Button 按钮
- Switch 开关（自锁按钮）
- Buzzer 蜂鸣器
- Fan 风扇，支持PWM调速
- Servo 舵机
- Stepper 步进电机（闭环电机还不支持）
- Relay 继电器
- LBS 基站定位，支持高德API 和 4G模组内置的定位
- GPS、GNSS 卫星定位
- RTC PCF8653时钟芯片
- Voice 语音输出，TTS播报

### 2.2 执行器、计划器、代理人

通过扩展vm模块，给执行器增加功能，实现具体的动作，比如：行走、投喂、吹风

``` lua
function vm.move(task, ctx, executor)
  local rpm = task.speed * 300 -- 换算具体频率和脉冲数
  local rounds = task.distance * 1600
  local time = components.move_stepper:start(rpm, rounds)
  ...
  return task.wait, time
end
```

注册计划器，将一系列动作抽象成任务

``` lua
planner.register("move", function(data)
    return {
        tasks = {{
            type = "move",
            speed = 2,
            distance = 10
        }}
    }
end)
```

注册命令，实现的远程控制

``` lua
agent.register("move", function(data)
    if robot.moving then
        return false, "已经在移动了"
    end
    -- 调用计划器，创建计划，然后交由执行器进行最终的动作执行
    return robot.plan("move", data)
end)
```

### 2.3 状态机

状态机主要用来维护设备的正确状态，保障任务的自动执行和取消，避免出现逻辑混乱，机器人变傻瓜

``` lua
robot.fsm:register("init", {
    name = "初始化",
    enter = function()
        battery.charge(false)
        components.led_power:turn_on()
        components.led_feed:turn_on()
        components.led_move:turn_on()
        ---
    end,
    leave = function()
    end,
    tick = function()

    end,
})

-- 切换对应状态
robot.fsm:switch("init", ...)

```

### 2.4 算法库

滤波算法

- 移动平均
- 中值
- 指数
- 互补
- 卡尔曼
- 粒子
- IIR

路径规划算法

- A*
- D*
- θ* 

PID 算法

- 增量
- 位置


# 二、基于物联小白实现的产品，智能网关、RTU、物联网机器人

## 1、BY-NEO-1.0

![BY-NEO-1.0](https://busycloud.cn/by-neo-1.0.jpg)

- 双SIM卡，内置5年18G流量
- 6路数字量输入，自定义有源和无源信号
- 6路继电器输出，5A，常开和常闭
- 4路模拟量，0-10V，可以通过拨码开关，切换至0-20mA
- 100M以太网接口，支持WAN和LAN模式，上网或为其他设备供网
- 高速CAN总线，支持NMEA协议


## 2、对虾养殖投喂机器人

![xiaopengxia](https://busycloud.cn/xiaopengxia.jpg)
![xiaopengxia](https://busycloud.cn/xiaopengxia2.jpg)

# 三、联系我们

南京本易物联网有限公司

- 邮箱：[jason@zgwit.com](mailto:jason@zgwit.com)
- 手机：[15161515197](tel:15161515197)(微信同号)

![微信](https://busycloud.cn/weixin.jpg)

# 四、开源协议

[GPL](https://github.com/zgwit/iot-noob/blob/main/LICENSE)

补充：产品仅限个人免费使用，商业需求请联系我们
