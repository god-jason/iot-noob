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

local _clouds = {}

-- 解析JSON
local function parse_json(callback, self)
    return function(topic, payload)
        log.info("mqtt message", topic, payload)
        local data, err = iot.json_decode(payload)
        if err then
            log.info("decode", payload, err)
            return
        end
        callback(self, topic, data)
    end
end

local Cloud = require("utils").class(require("event"))

function Cloud:init()
    -- 默认使用IMEI号作为ID
    if not self.id or #self.id == 0 then
        self.id = mobile.imei()
    end
    -- 生成秘钥， username:imei, password:md5(imei+date+key)
    -- local date = os.date("%Y-%m-%d") -- 系统可能还没获取到正确的时间
    self.clientid = self.clientid or self.id
    self.username = self.username or self.id
    self.password = self.password or crypto.md5(self.id .. self.key)

    -- 启动任务
    iot.start(Cloud.task, self)
end

-- 查找设备
function Cloud:find_device(device_id)
    -- 未传值，则使用网关设备
    if not device_id or #device_id == 0 or device_id == self.id then
        --data.device_id = self.id -- 赋值回传
        return master.device
    end
    return devices[device_id]
end

-- 上报设备数据
function Cloud:report_device_values(dev, all)
    if not self.client then
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
        self.client:publish("device/" .. dev.id .. "/values", data)
    end
end

-- 上报设备在线状态
function Cloud:report_device_status(dev)
    if not self.client then
        log.error("平台未连接")
        return
    end

    local now = os.time()

    local st

    -- 默认10分钟无数据离线
    if now - dev._updated > (self.sub_offline_timeout or 10) * 60 then
        st = "offline"
    else
        st = "online"
    end

    -- 状态变化才上传
    if dev._status ~= st then
        self.client:publish("device/" .. dev.id .. "/" .. st, nil)
        dev._status = st
    end
end

-- 处理配置操作
function Cloud:on_setting_operators(topic, data)
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

    self.client:publish(topic .. "/response", info or "成功")
end

-- 处理数据库操作
function Cloud:on_database_operators(topic, data)
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
    self.client:publish(topic .. "/response", info or "成功")
end

-- 远程下发配置
function Cloud:on_device_setting(topic, data)
    settings.update(data.name, data.content, data.version)
    -- 数据直接原路返回了
    self.client:publish(topic .. "/response", data)
end

-- 设备同步请求
function Cloud:on_device_sync(topic, data)
    local dev = self:find_device(data.device_id)
    if dev then
        local ret, info = dev:poll()
        if not ret then
            data.error = info
        end

        -- 上传数据
        self:report_values()
    else
        data.error = "设备不存在"
    end
    self.client:publish("device/" .. data.device_id .. "/sync/response", data)
end

-- 设备写请求
function Cloud:on_device_write(topic, data)
    local dev = self:find_device(data.device_id)
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
    self.client:publish("device/" .. data.device_id .. "/write/response", data)
end

-- 设备读请求
function Cloud:on_device_read(topic, data)
    local dev = self:find_device(data.device_id)
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
    self.client:publish("device/" .. data.device_id .. "/read/response", data)
end

-- 处理设备操作
function Cloud:on_action(topic, data)
    local dev = self:find_device(data.device_id)
    if dev then
        local ret, val = agent.execute(data.action, data.parameters or data.data)
        if ret then
            data.result = val
        else
            data.error = val
        end
    else
        data.error = "设备不存在"
    end
    self.client:publish("device/" .. data.device_id .. "/action/response", data)
end

-- 注册设备信息
function Cloud:register()
    log.info("register")

    -- 上报注册信息
    local info = {
        id = self.id,
        product_id = self.product_id,
        firmware = rtos.firmware(),
        version = VERSION,
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid()
    }

    -- 查找所有已经打开的连接
    if links then
        info.links = {} -- 上报连接，方便后台管理
        for k, v in pairs(links) do
            table.insert(info.links, {
                id = k,
                name = v.name,
                type = v.type
            })
        end
    end

    -- 同步配置
    if self.sync_settings then
        -- 配置文件版本号，上传服务器之后，自动同步
        info.settings = settings.versions
    end

    -- 同步数据库
    if self.sync_databases then

        -- 物模型
        info.models = {}
        local tab = database.load("model")
        for id, data in pairs(tab) do
            info.models[id] = data.version or 0
        end

        -- 设备关联的物模型
        tab = database.load("device")
        for id, data in pairs(tab) do
            if data.product_id and not info.models[data.product_id] then
                info.models[data.product_id] = 0 -- 同步物模型
            end
        end

        -- 内联设备
        tab = database.load("inline")
        for id, data in pairs(tab) do
            if data.product_id and not info.models[data.product_id] then
                info.models[data.product_id] = 0 -- 同步物模型
            end
        end

        local function syncTable(name)
            local sync = {}
            tab = database.load(name)
            for id, data in pairs(tab) do
                sync[id] = {
                    updated = data.updated,
                    created = data.created
                }
            end
            return sync
        end

        -- 同步数据库
        info.databases = {
            serial = syncTable("serial"), -- 串口连接
            -- socket = syncTable("socket"), -- 网口连接
            device = syncTable("device"), -- 子设备
            inline = syncTable("inline"), -- 内联设备
            binding = syncTable("binding"), -- 设备绑定
            scene = syncTable("scene"), -- 智能场景
            job = syncTable("job") -- 定时任务
        }

    end

    self.client:publish("device/" .. self.id .. "/register", info)
end

-- 上报所有设备
function Cloud:report_values(all)
    self:report_device_values(master.device, all)
end

-- 上报所有设备
function Cloud:report_devices_values(all)
    for id, dev in pairs(devices) do
        if dev.values and not dev.inline then
            self:report_device_values(dev, all)
        end
    end
end

-- 上报所有设备状态
function Cloud:report_devices_status()
    for id, dev in pairs(devices) do
        -- 只上报非内联子设备状态
        if dev ~= master.device and dev.values and not dev.inline then
            self:report_device_status(dev)
        end
    end
end

function Cloud:task()
    -- if mobile.status() ~= 1 then
    log.info("等待网络就绪")
    -- 等待网络就绪
    iot.wait("IP_READY")
    -- end

    -- 常亮网络灯（放这里不合适）
    if components.led_net then
        components.led_net:turn_on()
    end

    -- 连接云平台
    self.client = MqttClient:new(self)

    self.client:on_connect(function()
        -- 平台灯闪烁
        if components.led_cloud then
            components.led_cloud:turn_on()
        end
    end)

    self.client:on_disconnect(function()
        -- 平台灯闪烁
        if components.led_cloud then
            components.led_cloud:blink()
        end
    end)

    -- 打开
    local ret, err = self.client:open()

    if not ret then
        log.error("平台连接失败", err)
        return
    end

    log.info("平台连接成功")

    -- 订阅网关消息
    -- self.client:subscribe("device/" .. self.id .. "/database/+/+", parse_json(Cloud.on_database_operators, self))
    -- self.client:subscribe("device/" .. self.id .. "/setting/+/+", parse_json(Cloud.on_setting_operators, self))
    self.client:subscribe("device/" .. self.id .. "/setting", parse_json(Cloud.on_device_setting, self))
    self.client:subscribe("device/" .. self.id .. "/write", parse_json(Cloud.on_device_write, self))
    self.client:subscribe("device/" .. self.id .. "/read", parse_json(Cloud.on_device_read, self))
    self.client:subscribe("device/" .. self.id .. "/sync", parse_json(Cloud.on_device_sync, self))
    self.client:subscribe("device/" .. self.id .. "/action", parse_json(Cloud.on_action, self))

    -- 自动注册
    -- iot.on("MQTT_CONNECT_" .. cloud.id, register)
    self:register()

    -- 主设备上线
    self.client:publish("device/" .. self.id .. "/online", {})

    -- 主设备使用配置ID
    if not master.device.id then
        master.device.id = self.id
    end

    local all_interval = 600 -- 10分钟传一次全部数据
    local ticks = all_interval - 30 -- 开机30秒，先全部传一次

    while true do

        -- 上报数据
        ticks = ticks + 1
        if ticks > all_interval then
            ticks = 0

            -- 上传网关设备数据
            self:report_values(true)
            self:report_devices_values(true)
        else
            self:report_values()
            self:report_devices_values()
        end

        -- 子设备状态
        self:report_devices_status()

        -- 正在查看时，1秒上传一次
        if agent.watching then
            iot.sleep(1000)
        else
            -- 避免首次等60秒
            for i = 1, (self.interval or 60), 1 do
                if not agent.watching then
                    iot.sleep(1000)
                end
            end
        end
    end
end

function Cloud:close()
    self.client:close()
end

--- 发布消息
-- @param topic string 主题
-- @param payload string|table|nil 数据，支持string,table
-- @param qos integer|nil 质量
function Cloud:publish(topic, payload, qos)
    if not self.client then
        log.error("平台未连接")
        return
    end
    self.client:publish(topic, payload, qos)
end

-- 上传日志
iot.on("log", function(data)
    for i, c in ipairs(_clouds) do
        if c.log then
            c:publish("device/" .. c.id .. "/log", data)
        end
    end
end)

-- 上传错误
iot.on("error", function(data)
    for i, c in ipairs(_clouds) do
        if c.error then
            c:publish("device/" .. c.id .. "/log", "[设备错误] " .. data)
        end
    end
end)

-- 上传指令
iot.on("report", function(all)
    for i, c in ipairs(_clouds) do
        if c.report then
            c:report_values(all)
        end
    end
end)

-- 上传错误
iot.on("report_error", function(err)
    for i, c in ipairs(_clouds) do
        if c.error then
            c:publish("device/" .. c.id .. "/error", err)
        end
    end
end)

-- 上传错误
iot.on("clear_error", function()
    for i, c in ipairs(_clouds) do
        if c.error then
            c:publish("device/" .. c.id .. "/error/clear")
        end
    end
end)

-- 监听定位，并上传
iot.on("location", function(data)
    data = iot.json_encode(data, "12f") -- 默认精度只有2位，太低了
    for i, c in ipairs(_clouds) do
        if c.location then
            c:publish("device/" .. c.id .. "/location", data)
        end
    end
end)

function cloud.open()
    local clouds = {settings.cloud, settings.cloud1, settings.cloud1}

    -- 打开连接
    for i, v in ipairs(clouds) do
        if v.enable then
            local c = Cloud:new(v)
            table.insert(_clouds, c)
        end
    end
end

function cloud.close()
    for i, v in ipairs(_clouds) do
        v:close()
    end
end

boot.register("cloud", cloud, "settings")

settings.register("cloud", {
    enable = true,
    host = "iot.busycloud.cn",
    port = 1883,
    key = "noob",
    log = true,
    error = true,
    report = true,
    location = true,
    sync_settings = true,
    sync_databases = true
})

settings.register("cloud1", "cloud2")

return cloud
