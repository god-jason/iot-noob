--- 小白主程序
-- @module master
local master = {}

local tag = "master"

local commands = require("commands")
local configs = require("configs")
local gateway = require("gateway")
local MqttClient = require("mqtt_client")
local database = require("database")

--- @type MqttClient
local cloud = nil -- MqttClient:new()

local options = {}
local default_options = {
    enable = true,
    host = "hub.busycloud.cn",
    port = 1883,
    key = "master"
}

-- 解析JSON
local function parse_json(callback)
    return function(topic, payload)
        log.info(tag, "topic", topic)
        local data, err = iot.json_decode(payload)
        if err then
            log.info(tag, "decode", payload, err)
            return
        end
        callback(topic, data)
    end
end

-- 开始透传
local function on_pipe_start(topic, data)
    local link = gateway.get_link_instanse(data.link)
    if not link then
        return
    end

    cloud:subscribe("noob/" .. options.id .. "/link/" .. data.link .. "/down", function(t, d)
        link.write(d)
    end)

    link:watch(function(d)
        cloud:publish("noob/" .. options.id .. "/link/" .. data.link .. "/up", d)
    end)
end

-- 结束透传
local function on_pipe_stop(topic, data)
    local link = gateway.get_link_instanse(data.link)
    if not link then
        return
    end

    cloud:unsubscribe("noob/" .. options.id .. "/link/" .. data.link .. "/down")
    link:watch(nil)
end

-- 处理命令
local function on_command(topic, pkt)
    local ret
    local response
    local handler = commands[pkt.cmd]
    if handler then
        -- 加入异常处理
        ret, response = pcall(handler, pkt)
        if not ret then
            response = commands.error(response)
        end
    else
        response = commands.error("未知命令")
    end

    -- 复制消息ID
    if pkt._id ~= nil then
        response._id = pkt._id
    end

    if response ~= nil then
        cloud:publish("noob/" .. options.id .. "/command/response", response)
    end
end

-- 处理数据库操作
local function on_database(topic, data)
    local _, _, _, _, _, db, op = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "database", db, op)
    if op == "clear" then
        database.clear(db)
    elseif op == "delete" then
        database.delete(db, data)
    elseif op == "update" then
        database.update(db, data.id, data)
    elseif op == "insert" then
        database.insert(db, data.id, data)
    elseif op == "insertMany" then
        database.insertMany(db, data)
    elseif op == "insertArray" then
        database.insertArray(db, data)
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

    cloud:publish("noob/" .. options.id .. "/register", info)
end

-- 上报设备状态（周期执行）
local function report_status()
    log.info(tag, "report_status")

    local status = {
        date = os.date("%Y-%m-%d %H:%M:%S") -- 系统时间
    }

    -- 4G信息
    local scell = mobile.scell()
    status.net = {
        mcc = scell.mcc,
        mnc = scell.mnc,
        rssi = scell.rssi,
        csq = mobile.csq()
    }

    -- CPU使用信息
    status.cpu = {
        mhz = mcu.getClk(),
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
    if ret then
        status.fs = {
            total = block_total * block_size,
            used = block_used * block_size,
            block = block_size
        }
    end

    -- 电池使用
    -- local ret2, percent = battery.get()
    -- if ret2 then
    --     status.battery = percent
    -- end

    -- GPS定位
    -- local ret3, location = gnss.get()
    -- if ret2 then
    --     status.location = location
    -- end

    cloud:publish("noob/" .. options.id .. "/status", status)
end

function master.open()
    -- 加载配置
    options = configs.load_default(tag, default_options)
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

    -- 连接云平台
    cloud = MqttClient:new(options)
    local ret = cloud:open()

    if not ret then
        log.error(tag, "cloud open failed")
        return
    end

    -- 自动注册
    iot.on("MQTT_CONNECT_" .. cloud.id, register)

    -- 周期上报状态
    -- iot.setInterval(report_status, 300000) -- 5分钟 上传一次状态

    -- 订阅网关消息
    cloud:subscribe("noob/" .. options.id .. "/pipe/start", parse_json(on_pipe_start))
    cloud:subscribe("noob/" .. options.id .. "/pipe/stop", parse_json(on_pipe_stop))
    cloud:subscribe("noob/" .. options.id .. "/command", parse_json(on_command))
    cloud:subscribe("noob/" .. options.id .. "/database/+/+", parse_json(on_database))
end

function master.task()

    -- 等待网络就绪
    iot.wait("IP_READY")

    master.open();

    log.info(tag, "master broker connected start")

    register()
    iot.setInterval(report_status, 1000 * 60) -- 10分钟上传一次状态

    while true do
        -- 上报数据？
        -- local devices = gateway.get_all_device_instanse();
        -- for id, dev in pairs(devices) do
        --     -- TODO 定时上传
        --     local values = dev.values()
        -- end

        iot.sleep(60 * 1000)
    end
end

iot.start(master.task)

return master
