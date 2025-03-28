--- 网关程序入口
-- @module "noob"
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.02.08
local tag = "noob"
local noob = {}

local battery = require("battery")
local configs = require("configs")
local cloud = require("cloud")
local links = require("links")
local devices = require("devices")
local ota = require("ota")
local gnss = require("gnss")

-- 处理OTA升级
local function on_ota(topic, payload)
    log.info(tag, "on_ota", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- ota.download(data.url)
    sys.taskInit(ota.download, data.url)
end

-- 处理配置读取
local function on_config_read(topic, payload)
    log.info(tag, "on_config_read", topic)

    local base = "noob/" .. cloud.id() .. "/config/read/"
    local config = string.sub(topic, #base + 1)

    local r, c = configs.load(config)
    if not r then
        return
    end

    cloud.publish("noob/" .. cloud.id() .. "/config/content/" .. config, c)
end

-- 处理配置写入
local function on_config_write(topic, payload)
    log.info(tag, "on_config_write", topic, payload)

    local base = "noob/" .. cloud.id() .. "/config/write/"
    local config = string.sub(topic, #base + 1)

    configs.save(config, payload)
end

local function on_config_delete(topic, payload)
    log.info(tag, "on_config_delete", topic)

    local base = "noob/" .. cloud.id() .. "/config/delete/"
    local config = string.sub(topic, #base + 1)

    configs.delete(config)
end

local function on_config_download(topic, payload)
    log.info(tag, "on_config_download", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end

    configs.download(data.name, data.url)
end

-- 开始透传
local function on_pipe_start(topic, payload)
    log.info(tag, "on_pipe_start", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- data.link TODO close protocol
    local link = links.get(data.link)
    cloud.subscribe("noob/" .. cloud.id() .. "/" .. data.link .. "/down", function(topic, payload)
        link.write(payload)
    end)
    link.watch(function(data)
        cloud.publish("noob/" .. cloud.id() .. "/" .. data.link .. "/up", data)
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
    cloud.unsubscribe("noob/" .. cloud.id() .. "/" .. data.link .. "/down")
    link.watch(nil)
end

local function on_device_read(topic, payload)
    log.info(tag, "on_device_read", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end

    local dev = devices.get(data.id)
    if not dev then
        return
    end

    local ret, value = dev.get(data.key)
    if ret then
        cloud.publish("device/" .. data.id .. "/read", {
            key = data.key,
            value = value
        })
    end
end

local function on_device_write(topic, payload)
    log.info(tag, "on_device_write", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end

    local dev = devices.get(data.id)
    if not dev then
        return
    end

    local ret = dev.set(data.key, data.value)
end

local function on_device_action(topic, payload)
    log.info(tag, "on_device_action", payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end

    local dev = devices.get(data.id)
    if not dev then
        return
    end

    -- 执行一系列动作
    for _, action in ipairs(data) do
        sys.timerStart(function()
            dev.set(action.key, action.value)
        end, action.delay or 0)
    end
end

local function on_reboot(topic, payload)
    log.info(tag, "on_reboot", payload)
    sys.timerStart(rtos.reboot, 5000)
    log.info(tag, "reboot after 5s")

    -- TODO 关闭网关，保存历史
end

-- 上报设备信息
local function register()
    log.info(tag, "report_info")
    local info = {
        bsp = rtos.bsp(),
        version = rtos.version(),
        firmware = rtos.firmware(),
        build = rtos.buildDate(),
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid()
    }
    cloud.publish("noob/" .. cloud.id() .. "/register", info)
end

-- 上报设备状态（周期执行）
local function report_status()
    log.info(tag, "report_status")

    local status = {
        net = mobile.scell()
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

    cloud.publish("noob/" .. cloud.id() .. "/status", status)
end

--- 打开网关
function noob.open()
    -- 加载设备
    devices.load()

    -- 打开连接
    links.load()

    -- 连接云平台
    cloud.open()

    -- 自动注册
    sys.subscribe("CLOUD_CONNECTED", register)
    --sys.timerStart(register, 30000) -- 30秒上传信息

    -- 周期上报状态
    sys.timerLoopStart(report_status, 60000) -- 60秒上传一次状态

    -- 订阅网关消息
    cloud.subscribe("noob/" .. cloud.id() .. "/ota", on_ota)
    cloud.subscribe("noob/" .. cloud.id() .. "/config/read/#", on_config_read)
    cloud.subscribe("noob/" .. cloud.id() .. "/config/write/#", on_config_write)
    cloud.subscribe("noob/" .. cloud.id() .. "/config/delete/#", on_config_delete)
    cloud.subscribe("noob/" .. cloud.id() .. "/config/download", on_config_download)
    cloud.subscribe("noob/" .. cloud.id() .. "/pipe/start", on_pipe_start)
    cloud.subscribe("noob/" .. cloud.id() .. "/pipe/stop", on_pipe_stop)
    cloud.subscribe("noob/" .. cloud.id() .. "/device/read", on_device_read)
    cloud.subscribe("noob/" .. cloud.id() .. "/device/write", on_device_write)
    cloud.subscribe("noob/" .. cloud.id() .. "/device/action", on_device_action)
    cloud.subscribe("noob/" .. cloud.id() .. "/reboot", on_reboot)

    -- 订阅系统消息
    sys.subscribe("DEVICE_VALUES", function(dev, values)
        cloud.publish("device/" .. dev.product_id .. "/" .. dev.id .. "/property", values)
    end)
    sys.subscribe("DEVICE_EVENT", function(dev, event)
        cloud.publish("device/" .. dev.product_id .. "/" .. dev.id .. "/event", event)
    end)

end

--- 关闭网关
function noob.close()

end

return noob
