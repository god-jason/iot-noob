--- 物联大师平台连接
-- @module cloud
local cloud = {}

local log = iot.logger("cloud")

local boot = require("boot")

local agent = require("agent")
local settings = require("settings")
local configs = require("configs")
local MqttClient = require("mqtt_client")
local database = require("database")
local master = require("master")

local client = nil -- MqttClient:new()

local options = {}

local default_options = {
    enable = true,
    host = "iot.busycloud.cn",
    port = 1883,
    key = "noob"
}

-- 查找设备
local function find_device(data)
    -- 未传值，则使用网关设备
    if not data.device_id or #data.device_id == 0 or data.device_id == options.id then
        data.device_id = options.id -- 赋值回传
        return master.device
    end
    return devices[data.device_id]
end

-- 上报设备数据
local function report_device_values(dev, all)
    if not client then
        log.error("平台未连接")
        return
    end

    local has_data = false
    local data = {}

    local values = all and dev:values() or dev:modified_values(true)
    for k, v in pairs(values) do
        data[k] = v.value
        has_data = true
    end

    if has_data then
        client:publish("device/" .. dev.id .. "/values", data)
    end
end

-- 上报设备在线状态
local function report_device_status(dev)
    if not client then
        log.error("平台未连接")
        return
    end

    local now = os.time()

    local st = ""

    -- 默认10分钟无数据离线
    if now - dev._updated > (options.sub_offline_timeout or 10) * 60 then
        st = "offline"
    else
        st = "online"
    end

    -- 状态变化才上传
    if dev._status ~= st then
        client:publish("device/" .. dev.id .. "/" .. st, nil)
        dev._status = st
    end
end

-- 上报所有设备
function cloud.report_values(all)
    report_device_values(master.device, all)
end

-- 上报所有设备
function cloud.report_devices_values(all)
    for id, dev in pairs(devices) do
        if dev.values and not dev.inline then
            report_device_values(dev, all)
        end
    end
end

-- 上报所有设备状态
function cloud.report_devices_status()
    for id, dev in pairs(devices) do
        if dev.values and not dev.inline then
            report_device_status(dev)
        end
    end
end

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

-- 处理配置操作
local function on_setting_operators(topic, data)
    local _, _, _, _, _, cfg, op = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("config", cfg, op)
    local ret, info
    if op == "delete" then
        ret, info = configs.delete(cfg)
    elseif op == "write" then
        ret, info = configs.save(cfg, data)
    elseif op == "read" then
        ret, info = configs.load(cfg)
    else
        info = "未支持的配置操作"
    end

    client:publish(topic .. "/response", info or "成功")
end

-- 处理数据库操作
local function on_database_operators(topic, data)
    local _, _, _, _, _, db, op = topic:find("(.+)/(.+)/(.+)/(.+)/(.+)")
    log.info("database", db, op)
    local ret, info
    if op == "clear" then
        ret, info = database.clear(db)
    elseif op == "sync" then -- 同步数据库
        database.clear(db)
        ret, info = database.insertArray(db, data)
    elseif op == "delete" then
        ret, info = database.delete(db, data.id)
    elseif op == "update" then
        ret, info = database.update(db, data.id, data)
    elseif op == "insert" then
        ret, info = database.insert(db, data.id, data)
    elseif op == "insertMany" then
        ret, info = database.insertMany(db, data)
    elseif op == "insertArray" then
        ret, info = database.insertArray(db, data)
    else
        info = "未支持的数据库操作"
    end

    -- TODO 数据库操作，没有规定 msg_id等统一字段，只能将错误信息原路返回
    client:publish(topic .. "/response", info or "成功")
end

-- 远程下发配置
local function on_device_setting(topic, data)
    settings.update(data.name, data.content, data.version)
    -- 数据直接原路返回了
    client:publish(topic .. "/response", data)
end

-- 设备同步请求
local function on_device_sync(topic, data)
    local dev = find_device(data)
    if dev then
        local ret, info = dev:poll()
        if not ret then
            data.error = info
        end

        -- 上传数据
        cloud.report_values()
    else
        data.error = "设备不存在"
    end
    client:publish("device/" .. data.device_id .. "/sync/response", data)
end

-- 设备写请求
local function on_device_write(topic, data)
    local dev = find_device(data)
    if dev then
        data.results = {}
        for k, v in pairs(data.values) do
            local ret, info = dev:set(k, v)
            if ret then
                data.results[k] = info
            else
                data.error = info
                break
            end
        end
    else
        data.error = "设备不存在"
    end
    client:publish("device/" .. data.device_id .. "/write/response", data)
end

-- 设备读请求
local function on_device_read(topic, data)
    local dev = find_device(data)
    if dev then
        data.values = {}
        for _, k in ipairs(data) do
            local ret, val = dev:get(k)
            if ret then
                data.values[k] = val
            else
                data.error = val
                break
            end
        end
    else
        data.error = "设备不存在"
    end
    client:publish("device/" .. data.device_id .. "/read/response", data)
end

-- 处理设备操作
local function on_action(topic, data)
    local dev = find_device(data)
    if dev then
        local ret, val = agent.execute(data.action, data.parameters)
        if ret then
            data.result = val
        else
            data.error = val
        end
    else
        data.error = "设备不存在"
    end
    client:publish("device/" .. data.device_id .. "/action/response", data)
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

-- 注册设备信息
local function register()
    log.info("register")

    local info = {
        id = options.id,
        product_id = options.product_id,
        firmware = rtos.firmware(),
        version = VERSION,
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid(),

        -- TODO 配置同步改为独立
        settings = settings.versions,

        -- TODO 数据库同步改为独立
        databases = {
            model = sync_table("model"),
            device = sync_table("device")
        }
    }

    client:publish("device/" .. options.id .. "/register", info)
end

--- 发布消息
-- @param topic string 主题
-- @param payload string|table|nil 数据，支持string,table
-- @param qos integer|nil 质量
function cloud.publish(topic, payload, qos)
    if not client then
        log.error("平台未连接")
        return
    end
    client:publish(topic, payload, qos)
end

-- 上报错误
function cloud.report_error(err)
    if not client then
        log.error("平台未连接")
        return
    end
    client:publish("device/" .. options.id .. "/error", err)
end

-- 清除错误
function cloud.clear_error()
    if not client then
        log.error("平台未连接")
        return
    end
    client:publish("device/" .. options.id .. "/error/clear", nil)
end

local function master_task()

    if mobile.status() ~= 1 then
        log.info("等待网络就绪")
        -- 等待网络就绪
        iot.wait("IP_READY")
    end

    -- 常亮网络灯（放这里不合适）
    if components.led_net then
        components.led_net:on()
    end

    -- 加载配置
    options = settings.cloud

    -- 默认使用IMEI号作为ID
    if not options.id or #options.id == 0 then
        options.id = mobile.imei()
    end

    -- 生成秘钥， username:imei, password:md5(imei+date+key)
    -- local date = os.date("%Y-%m-%d") -- 系统可能还没获取到正确的时间
    options.clientid = options.clientid or options.id
    options.username = options.username or options.id
    options.password = options.password or crypto.md5(options.id .. options.key)

    -- 连接云平台
    client = MqttClient:new(options)

    client:on_connect(function()
        -- 平台灯闪烁
        if components.led_cloud then
            components.led_cloud:on()
        end
    end)

    client:on_disconnect(function()
        -- 平台灯闪烁
        if components.led_cloud then
            components.led_cloud:blink()
        end
    end)

    -- 打开
    local ret, err = client:open()

    if not ret then
        log.error("平台连接失败", err)
        return
    end

    log.info("平台连接成功")

    -- 上传日志
    iot.on("log", function(data)
        if client then
            client:publish("device/" .. options.id .. "/log", data)
        end
    end)

    -- 上传错误
    iot.on("error", function(data)
        if client then
            client:publish("device/" .. options.id .. "/log", "[设备错误] " .. data)
        end
    end)

    -- 上传指令
    iot.on("report", function(all)
        cloud.report_values(all)
    end)

    iot.emit("MASTER_READY")

    -- 订阅网关消息
    client:subscribe("device/" .. options.id .. "/database/+/+", parse_json(on_database_operators))
    client:subscribe("device/" .. options.id .. "/setting/+/+", parse_json(on_setting_operators))
    client:subscribe("device/" .. options.id .. "/setting", parse_json(on_device_setting))
    client:subscribe("device/" .. options.id .. "/write", parse_json(on_device_write))
    client:subscribe("device/" .. options.id .. "/read", parse_json(on_device_read))
    client:subscribe("device/" .. options.id .. "/sync", parse_json(on_device_sync))
    client:subscribe("device/" .. options.id .. "/action", parse_json(on_action))

    -- 自动注册
    -- iot.on("MQTT_CONNECT_" .. cloud.id, register)
    register()

    -- 在线
    client:publish("device/" .. options.id .. "/online", {})

    -- 主设备使用配置ID
    master.device.id = options.id

    local all_interval = 600 -- 10分钟传一次全部数据
    local ticks = all_interval - 30 -- 开机30秒，先全部传一次

    while true do

        -- 上报数据
        ticks = ticks + 1
        if ticks > all_interval then
            ticks = 0

            -- 上传网关设备数据
            cloud.report_values(true)
            cloud.report_devices_values(true)
        else
            cloud.report_values()
            cloud.report_devices_values()
        end

        -- 子设备状态
        cloud.report_devices_status()

        -- 正在查看时，1秒上传一次
        if agent.watching then
            iot.sleep(1000)
        else
            -- 避免首次等60秒
            for i = 1, (options.interval or 60), 1 do
                if not agent.watching then
                    iot.sleep(1000)
                end
            end
        end
    end
end

function cloud.open()
    iot.start(master_task)
end

function cloud.close()
    -- 关闭连接
    if client then
        client:close()
        client = nil
    end
end

cloud.deps = {"settings"}
boot.register("cloud", cloud)

settings.register("cloud", default_options)

return cloud
