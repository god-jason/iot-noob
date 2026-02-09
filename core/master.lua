--- 小白主程序
-- @module master
local master = {}

local tag = "master"

local actions = require("actions")
local commands = require("commands")
local settings = require("settings")
local configs = require("configs")
local gateway = require("gateway")
local MqttClient = require("mqtt_client")
local database = require("database")

--- @type MqttClient
local cloud = nil -- MqttClient:new()

local options = {}
local default_options = {
    enable = true,
    host = "iot.busycloud.cn",
    port = 1883,
    key = "noob"
}

-- 解析JSON
local function parse_json(callback)
    return function(topic, payload)
        log.info(tag, "mqtt message", topic, payload)
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
        cloud:publish("device/" .. options.id .. "/command/response", response)
    end
end

-- 处理配置操作
local function on_config(topic, data)
    local _, _, _, _, _, cfg, op = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "config", cfg, op)
    if op == "delete" then
        configs.delete(cfg)
    elseif op == "save" then
        configs.save(cfg, data)
    elseif op == "load" then
        local config = configs.load(cfg)
        cloud:publish("device/" .. options.id .. "/config/" .. cfg .. "/read/response", config)
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

-- 处理事件操作
local function on_action(topic, data)
    local _, _, _, _, _, action = topic:find("(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "action", action)

    local handler = actions[action]
    if type(handler) == "function" then
        local ret, dat = handler(data)
        cloud:publish(topic .. "/response", {
            ok = ret,
            data = dat
        })
    else
        cloud:publish(topic .. "/response", {
            ok = false,
            error = "找不到响应"
        })
    end
end

local function on_setting(topic, data)
    settings.update(data.name, data.content, data.version)

    cloud:publish(topic .. "/response", {
        ok = true
    })
end

local function on_setting_read(topic, data)
    local _, _, _, _, _, setting, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "setting read", setting)
    cloud:publish(topic .. "/response", settings[setting])
end

-- 同步表数据
local function sync_table(col)
    local results = {}
    local tab = database.load(col)
    for id, data in pairs(tab) do
        results[id] = {
            updated = data.updated,
            created = data.created,
            product_id = data.product_id
        }
    end
    return results
end

-- 上报设备信息 TODO 改为配置文件
local function register()
    log.info(tag, "register")
    local info = {
        id = mobile.imei(),
        product_id = options.product_id,
        bsp = rtos.bsp(),
        firmware = rtos.firmware(),
        version = VERSION,
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid(),
        settings = settings.versions,
        databases = {
            link = sync_table("link"),
            model = sync_table("model"),
            device = sync_table("device")
        }
    }

    cloud:publish("device/" .. options.id .. "/register", info)
end

-- 变化上传
local status = {}
local changed = {}
local function put_status(k, v)
    if status[k] ~= v then
        status[k] = v
        changed[k] = v
    end
end

-- 上报设备状态（周期执行）
local function report_status()
    log.info(tag, "report_status")

    put_status("csq", mobile.csq())
    local total, used, top = rtos.meminfo()
    put_status("memory", used)
    put_status("version", VERSION)

    -- 变化上传，节省流量
    cloud:publish("device/" .. options.id .. "/values", changed)
    changed = {}
end

-- 上报子设备数据（周期执行）
local function report_sub_devices()
    local devices = gateway.get_all_device_instanse();
    for id, dev in pairs(devices) do
        local values = dev:values()

        local has_data = false
        local data = {}
        for k, v in pairs(values) do
            data[k] = v.value
            has_data = true
        end

        if has_data then
            cloud:publish("device/" .. id .. "/values", data)
        end
    end
end

-- 定时上报状态
local function report_sub_devices_status()
    local now = os.time()

    local devices = gateway.get_all_device_instanse();
    for id, dev in pairs(devices) do
        local status = ""

        -- 10分钟无数据离线
        if now - dev._updated > 10 * 60 then
            status = "offline"
        else
            status = "online"
        end

        -- 状态变化才上传
        if dev._status ~= status then
            cloud:publish("device/" .. id .. "/" .. status, nil)
            dev._status = status
        end
    end
end

-- 设备写请求
local function on_write(topic, data)
    local _, _, _, id, _ = topic:find("(.+)/(.+)/(.+)")
    log.info(tag, "on_write", id, data)
    local dev = gateway.get_device_instanse(id)
    if dev then
        for k, v in pairs(data) do
            dev:set(k, v)
        end
    end
end

-- 子设备写请求
local function on_sub_write(topic, data)
    local _, _, _, id, _, sub, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "on_sub_write", id, sub, data)
    local dev = gateway.get_device_instanse(sub)
    if dev then
        for k, v in pairs(data) do
            dev:set(k, v)
        end
    end
end

-- 设备读请求
local function on_read(topic, data)
    local _, _, _, id, _ = topic:find("(.+)/(.+)/(.+)")
    log.info(tag, "on_read", id, data)
    local dev = gateway.get_device_instanse(id)
    if dev then
        local results = {}
        for _, k in ipairs(data) do
            local v = dev:get(k)
            results[k] = v
        end
        cloud:publish("device/" .. id .. "/read/response", results)
    end
end

-- 子设备读请求
local function on_sub_read(topic, data)
    local _, _, _, id, _, sub, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "on_sub_read", id, sub, data)
    local dev = gateway.get_device_instanse(sub)
    if dev then
        local results = {}
        for _, k in ipairs(data) do
            local v = dev:get(k)
            results[k] = v
        end
        cloud:publish("device/" .. sub .. "/read/response", results)
    end
end

-- 设备同步请求
local function on_sync(topic, data)
    local _, _, _, id, _ = topic:find("(.+)/(.+)/(.+)")
    log.info(tag, "on_sync", id)
    local dev = gateway.get_device_instanse(id)
    if dev then
        dev:poll()
    end
end

-- 子设备同步请求
local function on_sub_sync(topic, data)
    local _, _, _, id, _, sub, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "on_sub_sync", id, sub)
    local dev = gateway.get_device_instanse(sub)
    if dev then
        dev:poll(data)
    end
end

local function on_sub_action(topic, data)
    local _, _, _, id, _, sub, _, action = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info(tag, "sub action", sub, action)

    -- TODO 子设备操作

end

function master.open()
    -- 加载配置
    options = configs.load_default("master", default_options)

    -- 默认使用IMEI号作为ID
    if not options.id or #options.id == 0 then
        options.id = mobile.imei()
    end
    options.id = options.id

    -- 生成秘钥， username:imei, password:md5(imei+date+key)
    -- local date = os.date("%Y-%m-%d") -- 系统可能还没获取到正确的时间
    options.clientid = options.id
    options.username = options.id
    options.password = crypto.md5(options.id .. options.key)

    -- 连接云平台
    cloud = MqttClient:new(options)
    local ret = cloud:open()

    if not ret then
        log.error(tag, "cloud open failed")
        return
    end

    log.info(tag, "master broker connected")

    -- 订阅网关消息
    cloud:subscribe("device/" .. options.id .. "/command", parse_json(on_command))
    cloud:subscribe("device/" .. options.id .. "/config/+/+", parse_json(on_config))
    cloud:subscribe("device/" .. options.id .. "/database/+/+", parse_json(on_database))
    cloud:subscribe("device/" .. options.id .. "/write", parse_json(on_write))
    cloud:subscribe("device/" .. options.id .. "/sub/+/write", parse_json(on_sub_write))
    cloud:subscribe("device/" .. options.id .. "/read", parse_json(on_read))
    cloud:subscribe("device/" .. options.id .. "/sub/+/read", parse_json(on_sub_read))
    cloud:subscribe("device/" .. options.id .. "/sync", parse_json(on_sync))
    cloud:subscribe("device/" .. options.id .. "/sub/+/sync", parse_json(on_sub_sync))
    cloud:subscribe("device/" .. options.id .. "/action/+", parse_json(on_action))
    cloud:subscribe("device/" .. options.id .. "/sub/+/action/+", parse_json(on_sub_action))
    cloud:subscribe("device/" .. options.id .. "/setting", parse_json(on_setting))
    cloud:subscribe("device/" .. options.id .. "/setting/+/read", parse_json(on_setting_read))

    -- 自动注册
    -- iot.on("MQTT_CONNECT_" .. cloud.id, register)
    register()

    -- 在线
    cloud:publish("device/" .. options.id .. "/online", {})

    -- 周期上报状态
    -- iot.setInterval(report_status, 300000) -- 5分钟 上传一次状态
end

function master.task()
    -- 等待网络就绪
    iot.wait("IP_READY")

    master.open()
    log.info(tag, "master broker connected")

    -- 30分钟上传一次全部数据
    iot.setInterval(function()
        status = {}
    end, 10 * 60 * 1000)

    -- report_sub_devices_status()
    iot.setInterval(report_sub_devices_status, 10 * 60 * 1000) -- 每10分钟 上传一次子设备状态
    iot.setTimeout(report_sub_devices_status, 2 * 60 * 1000) -- 2分钟 先上传一次状态

    while true do

        -- 设备状态上报
        report_status()

        -- 子设备数据上报
        report_sub_devices()

        -- 正在查看时，1秒上传一次
        if actions.watching then
            iot.sleep(1000)
        else
            -- 避免首次等60秒
            for i = 1, 60, 1 do
                if not actions.watching then
                    iot.sleep(1000)
                end
            end
        end
    end
end

iot.start(master.task)

return master
