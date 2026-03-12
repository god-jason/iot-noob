--- 物联大师平台连接
-- @module master
local master = {}

local log = iot.logger("master")

local boot = require("boot")

local agent = require("agent")
local settings = require("settings")
local configs = require("configs")
local MqttClient = require("mqtt_client")
local database = require("database")
local gateway = require("gateway")

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
        log.info("mqtt message", topic, payload)
        local data, err = iot.json_decode(payload)
        if err then
            log.info("decode", payload, err)
            return
        end
        callback(topic, data)
    end
end

-- 开始透传
local function on_pipe_start(topic, data)
    local link = links[data.link]
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
    local link = links[data.link]
    if not link then
        return
    end

    cloud:unsubscribe("noob/" .. options.id .. "/link/" .. data.link .. "/down")
    link:watch(nil)
end

-- 处理配置操作
local function on_config(topic, data)
    local _, _, _, _, _, cfg, op = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("config", cfg, op)
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
    log.info("database", db, op)
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

local function on_setting(topic, data)
    settings.update(data.name, data.content, data.version)

    cloud:publish(topic .. "/response", {
        ok = true
    })
end

local function on_setting_read(topic, data)
    local _, _, _, _, _, setting, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("setting read", setting)
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

-- 上报设备信息
local function register()
    log.info("register")

    local info = {
        id = mobile.imei(),
        product_id = options.product_id,
        bsp = rtos.bsp(),
        firmware = rtos.firmware(),
        version = VERSION,
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid(),

        -- TODO 配置同步改为独立
        settings = settings.versions,

        -- TODO 数据库同步改为独立
        databases = {
            link = sync_table("link"),
            model = sync_table("model"),
            device = sync_table("device")
        }
    }

    cloud:publish("device/" .. options.id .. "/register", info)
end

-- 上报设备状态（周期执行）
local function report_status(all)
    log.info("report_status", all)

    local has_data = false
    local data = {}

    local dev = gateway.device
    local values = all and dev:values() or dev:modified_values(true)
    for k, v in pairs(values) do
        data[k] = v.value
        has_data = true
    end

    if has_data then
        cloud:publish("device/" .. options.id .. "/values", data)
    end
end

-- 上报子设备数据（周期执行）
local function report_sub_devices(all)
    log.info("report_sub_devices", all)

    for id, dev in pairs(devices) do
        if dev.values and not dev.inline then
            local values = all and dev:values() or dev:modified_values(true)

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
end

-- 定时上报状态
local function report_sub_devices_status()
    local now = os.time()

    for id, dev in pairs(devices) do
        if dev._values then
            local st = ""

            -- 10分钟无数据离线 TODO 参数
            if now - dev._updated > 10 * 60 then
                st = "offline"
            else
                st = "online"
            end

            -- 状态变化才上传
            if dev._status ~= st then
                cloud:publish("device/" .. id .. "/" .. st, nil)
                dev._status = st
            end
        end
    end
end

-- 设备写请求
local function on_write(topic, data)
    local _, _, _, id, _ = topic:find("(.+)/(.+)/(.+)")
    log.info("on_write", id, data)
    local dev = gateway.device
    for k, v in pairs(data) do
        dev:set(k, v)
    end
end

-- 子设备写请求
local function on_sub_write(topic, data)
    local _, _, _, id, _, sub, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("on_sub_write", id, sub, data)
    local dev = devices[sub]
    if dev then
        for k, v in pairs(data) do
            dev:set(k, v)
        end
    end
end

-- 设备读请求
local function on_read(topic, data)
    local _, _, _, id, _ = topic:find("(.+)/(.+)/(.+)")
    log.info("on_read", id, data)
    local dev = gateway.device
    local results = {}
    for _, k in ipairs(data) do
        local v = dev:get(k)
        results[k] = v
    end
    cloud:publish("device/" .. id .. "/read/response", results)
end

-- 子设备读请求
local function on_sub_read(topic, data)
    local _, _, _, id, _, sub, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("on_sub_read", id, sub, data)
    local dev = devices[sub]
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
    log.info("on_sync", id)
    local dev = gateway.device
    dev:poll()
end

-- 子设备同步请求
local function on_sub_sync(topic, data)
    local _, _, _, id, _, sub, _ = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("on_sub_sync", id, sub)
    local dev = devices[sub]
    if dev then
        dev:poll(data)
    end
end

-- 处理设备操作
local function on_action(topic, data)
    local _, _, _, _, _, action = topic:find("(.+)/(.+)/(.+)/(.+)")
    log.info("action", action)

    local ret, err = agent.execute(action, data)
    cloud:publish(topic .. "/response", {
        ok = ret,
        data = err
    })
end

-- 处理子设备操作
local function on_sub_action(topic, data)
    local _, _, _, id, _, sub, _, action = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("sub action", sub, action)

    -- TODO 子设备操作

end

local function master_task()
    -- 等待网络就绪
    iot.wait("IP_READY")

    -- 加载配置
    options = settings.master or default_options

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
    local ret, err = cloud:open()

    if not ret then
        log.error("平台连接失败", err)
        return
    end

    log.info("平台连接成功")

    iot.emit("MASTER_READY")

    -- 订阅网关消息
    cloud:subscribe("device/" .. options.id .. "/database/+/+", parse_json(on_database))
    cloud:subscribe("device/" .. options.id .. "/config/+/+", parse_json(on_config))
    cloud:subscribe("device/" .. options.id .. "/setting", parse_json(on_setting))
    cloud:subscribe("device/" .. options.id .. "/setting/+/read", parse_json(on_setting_read))
    cloud:subscribe("device/" .. options.id .. "/write", parse_json(on_write))
    cloud:subscribe("device/" .. options.id .. "/read", parse_json(on_read))
    cloud:subscribe("device/" .. options.id .. "/sync", parse_json(on_sync))
    cloud:subscribe("device/" .. options.id .. "/action/+", parse_json(on_action))
    cloud:subscribe("device/" .. options.id .. "/sub/+/write", parse_json(on_sub_write))
    cloud:subscribe("device/" .. options.id .. "/sub/+/read", parse_json(on_sub_read))
    cloud:subscribe("device/" .. options.id .. "/sub/+/sync", parse_json(on_sub_sync))
    cloud:subscribe("device/" .. options.id .. "/sub/+/action/+", parse_json(on_sub_action))

    -- 自动注册
    -- iot.on("MQTT_CONNECT_" .. cloud.id, register)
    register()

    -- 在线
    cloud:publish("device/" .. options.id .. "/online", {})

    -- 周期上报状态
    -- iot.setInterval(report_status, 300000) -- 5分钟 上传一次状态

    -- 10分钟上传一次全部数据
    iot.setInterval(report_status, 10 * 60 * 1000, true)
    iot.setInterval(report_sub_devices_status, 10 * 60 * 1000, true)

    while true do

        -- 设备状态上报
        report_status()

        -- 子设备数据上报
        report_sub_devices()

        -- 正在查看时，1秒上传一次
        if agent.watching then
            iot.sleep(1000)
        else
            -- 避免首次等60秒
            for i = 1, 60, 1 do
                if not agent.watching then
                    iot.sleep(1000)
                end
            end
        end
    end
end

function master.open()
    iot.start(master_task)
end

function master.close()
    -- 关闭连接
end

master.deps = {"settings"}
boot.register("master", master)

settings.register("master", default_options)

return master
