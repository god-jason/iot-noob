--- 网关程序入口
-- @module "noob"
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.02.08
local tag = "noob"
local noob = {}

local commands = require("commands")
local configs = require("configs")
local links = require("links")
local devices = require("devices")
local products = require("products")
local battery = require("battery")
local gnss = require("gnss")

local MQTT = require("mqtt_ext")

--- @type MQTT
local cloud = nil -- MQTT:new()

local options = {}
local default_options = {
    enable = true,
    host = "hub.busycloud.cn",
    port = 1883,
    key = "noob"
}

-- 开始透传
local function on_pipe_start(topic, payload)
    log.info(tag, "on_pipe_start", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- data.link TODO close protocol
    local link = links.get(data.link)
    cloud:subscribe("noob/" .. options.id .. "/" .. data.link .. "/down", function(topic, payload)
        link.write(payload)
    end)
    link:watch(function(data)
        cloud:publish("noob/" .. options.id .. "/" .. data.link .. "/up", data)
    end)
end

-- 结束透传
local function on_pipe_stop(topic, payload)
    log.info(tag, "on_pipe_stop", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- data.link TODO open protocol
    local link = links.get(data.link)
    cloud:unsubscribe("noob/" .. options.id .. "/" .. data.link .. "/down")
    link:watch(nil)
end

local function on_command(topic, payload)
    log.info(tag, "on_command", payload)
    -- local base = "noob/" .. options.id .. "/command/"
    -- local cmd = string.sub(topic, #base + 1)

    local response
    local pkt, ret, err = json.decode(payload)
    if ret == 1 then
        local handler = commands[pkt.cmd]
        if handler then
            response = handler(pkt)
        else
            response = commands.error("invalid command")
        end
    else
        response = commands.error(err)
    end

    -- 复制ID
    if pkt.mid ~= nil then
        response.mid = pkt.mid
    end

    if response ~= nil then
        cloud:publish("noob/" .. options.id .. "/command/response", response)
    end
end

-- 上报设备信息
local function register()
    log.info(tag, "report_info")
    local info = {
        bsp = rtos.bsp(),
        firmware = rtos.firmware(),
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid()
    }

    -- 同步信息，服务器接收后，远程下发数据
    local ret, links = configs.load("links")
    if ret then
        info.links = #links
    end
    local ret, devices = configs.load("devices")
    if ret then
        info.devices = #devices
    end

    -- 需要同步的配置
    local ret, configs = products.wanted()
    if ret then
        info.wanted_configs = configs
    end

    cloud:publish("noob/" .. options.id .. "/register", info)
end

-- 上报设备状态（周期执行）
local function report_status()
    log.info(tag, "report_status")

    local status = {
        net = mobile.scell(),
        date = os.date("%Y-%m-%d %H:%M:%S") -- 系统时间
    }

    -- 内存使用信息
    local total, used, top = rtos.meminfo()
    status.mem = {
        total = total,
        used = used,
        top = top
    }

    -- 文件系统使用
    local ret, block_total, block_used, block_size = fs.fsstat()
    status.fs = {
        total = block_total * block_size,
        used = block_used * block_size,
        block = block_size
    }

    -- 电池使用
    local ret2, percent = battery.get()
    if ret2 then
        status.battery = percent
    end

    -- GPS定位
    local ret3, location = gnss.get()
    if ret2 then
        status.location = location
    end

    cloud:publish("noob/" .. options.id .. "/status", status)
end

function noob.init()
    -- 加载配置
    local ret
    ret, options = configs.load_default(tag, default_options)
    if not options.enable then
        log.info(tag, "disabled")
        return
    end

    -- 默认使用IMEI号作为ID
    if not options.id or #options.id == 0 then
        options.id = mobile.imei()
    end
    options.id = options.id

    -- 生成秘钥， username:imei, password:md5(imei+date+key)
    -- local date = os.date("%Y-%m-%d") -- 系统可能还没获取到正确的时间
    options.clienid = options.id
    options.username = options.id
    options.password = crypto.md5(options.id .. options.key)
end

--- 打开网关
function noob.open()
    -- 连接云平台
    cloud = MQTT:new(options)
    local ret = cloud:open()

    if not ret then
        log.error(tag, "cloud open failed")
        return
    end

    -- 自动注册
    sys.subscribe("MQTT_CONNECT_" .. cloud.id, register)

    -- 周期上报状态
    sys.timerLoopStart(report_status, 300000) -- 5分钟 上传一次状态

    -- 订阅网关消息
    cloud:subscribe("noob/" .. options.id .. "/pipe/start", on_pipe_start)
    cloud:subscribe("noob/" .. options.id .. "/pipe/stop", on_pipe_stop)
    cloud:subscribe("noob/" .. options.id .. "/command", on_command)

    -- 订阅系统消息

    -- 设备属性上报
    sys.subscribe("DEVICE_VALUES", function(dev, values)
        cloud:publish("device/" .. dev.product_id .. "/" .. dev.id .. "/property", values)
    end)

    -- 设备事件上报
    sys.subscribe("DEVICE_EVENT", function(dev, event)
        cloud:publish("device/" .. dev.product_id .. "/" .. dev.id .. "/event", event)
    end)

end

--- 关闭网关
function noob.close()
    cloud:close()
    cloud = nil
end

local noob_ok = false

sys.subscribe("IP_READY", function()
    -- 启动网关系统程序
    if not noob_ok then
        noob.open()
        noob_ok = true
    end
end)

-- 初始化
noob.init()

return noob
