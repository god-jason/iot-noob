--- 启动代码
--- @module "boot"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.17
local tag = "boot"

-- 引入sys，方便使用
_G.sys = require("sys")
_G.sysplus = require("sysplus")

local configs = require("configs")

log.info(tag, PROJECT, VERSION)
log.info(tag, "last power reson", pm.lastReson())

-- 看门狗守护
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

local sntp_sync_ok = false

-- 指示灯
local led = require("led")

local function ip_ready()
    log.info(tag, "IP_READY")

    led.on("net")

    -- 同步时钟（联通卡不会自动同步时钟，所以必须手动调整）
    if not sntp_sync_ok then
        socket.sntp()
        -- socket.sntp("ntp.aliyun.com") --自定义sntp服务器地址
        -- socket.sntp({"ntp.aliyun.com","ntp1.aliyun.com","ntp2.aliyun.com"}) --sntp自定义服务器地址
        -- socket.sntp(nil, socket.ETH0) --sntp自定义适配器序号
    end
    -- TODO 其他任务，比如连接云服务器等 

end

local function ip_lose()
    log.info(tag, "IP_LOSE")
    led.off("net")
end

local function ntp_sync()
    sntp_sync_ok = true
    -- 设置到RTC时钟芯片
    require("clock").write()
end

local function boot_task()
    log.info(tag, "boot_task")

    -- 加载全局配置文件
    local ret, opts = configs.load("board")
    if not ret then
        log.error(tag, "you should configure your board.json")
        opts = {}
    end

    -- 初始化外设
    require("tools").init() -- SD卡 
    require("sd").init(opts.sd) -- SD卡 
    require("battery").init(opts.battery) -- 电池
    require("clock").init(opts.clock) -- 初始化时钟芯片
    require("led").init(opts.led) -- LED灯光
    require("lan").init(opts.lan) -- 以太网
    require("input").init(opts.input) -- 输入
    require("output").init(opts.output) -- 输入
    require("ext_adc").init(opts.ext_adc) -- 外部ADC
    require("gnss").init(opts.gnss) -- GPS定位
    require("serial").init(opts.serial) -- 串口

    -- 启动平台连接
    require("cloud").init() -- 平台

    -- gnss.init() --GPS定位

    -- 加载连接器
    require("link_serial")
    -- require("link_tcp_client")

    -- 加载协议库
    require("modbus")
    -- require("cjt188")
    -- require("dlt645")
    -- require("s7")

    -- 启动网关系统程序
    require("noob").open()

    log.info(tag, "boot_task exit")
end

sys.subscribe("IP_READY", ip_ready)
sys.subscribe("IP_LOSE", ip_lose)
sys.subscribe("NTP_UPDATE", ntp_sync)

sys.taskInit(boot_task)
