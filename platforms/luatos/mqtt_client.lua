--- MQTT封装
-- @module mqtt_client
local MqttClient = {}
MqttClient.__index = MqttClient

local log = iot.logger("MqttClient")

--- 自增ID
local increment = 1

---创建实例
-- @param opts table
-- @return table
function MqttClient:new(opts)
    local client = setmetatable({}, self)
    client.id = increment
    increment = increment + 1
    client.options = opts -- 参数
    client.client = nil -- MQTT连接
    client.subs = {} -- 订阅历史
    client.sub_tree = {
        children = {}, -- topic->sub_tree
        callbacks = {}
    } -- 订阅树

    -- 发送和接收队列
    client.pub_queue = {}
    client.sub_queue = {}
    return client
end

--- 查询订阅树
local function find_callback(node, topics, index, topic, payload)
    -- 叶子节点为空，执行回调
    if #topics < index then
        for _, cb in ipairs(node.callbacks) do
            cb(topic, payload)
        end
        return
    end

    -- 全部
    local sub = node.children["#"]
    if sub ~= nil then
        -- find_callback(sub, {}, 1, topic, payload)
        for _, cb in ipairs(sub.callbacks) do
            cb(topic, payload)
        end
    end

    -- 子级
    sub = node.children["+"]
    if sub ~= nil then
        find_callback(sub, topics, index + 1, topic, payload)
    end

    -- 通配子级
    local t = topics[index]
    sub = node.children[t]
    if sub ~= nil then
        find_callback(sub, topics, index + 1, topic, payload)
    end
end

---打开平台
-- @return boolean 成功与否
function MqttClient:open()
    if mqtt == nil then
        log.error("bsp does not have mqtt lib")
        return false, "缺少MQTT"
    end

    log.info("connect", self.options.host, self.options.port, self.options.clientid, self.options.username,
        self.options.password)

    -- 创建客户端
    self.client = mqtt.create(nil, self.options.host, self.options.port, self.options.ssl)
    if self.client == nil then
        log.error("create client failed")
        return false, "创建MQTT失败"
    end

    -- 调试
    if self.options.debug then
        self.client:debug(true)
    end

    -- 鉴权
    self.client:auth(self.options.clientid, self.options.username, self.options.password)

    self.client:keepalive(self.options.keepalive or 240) -- 默认值240s

    self.client:autoreconn(true, self.options.reconnect_timeout or 5000) -- 自动重连机制 ms

    if self.options.will ~= nil then
        self.client:will(self.options.will.topic, self.options.will.payload)
    end

    -- 注册回调
    self.client:on(function(client, event, topic, payload)
        log.info("event", event, client, topic, payload)

        if event == "recv" then
            table.insert(self.sub_queue, {
                topic = topic,
                payload = payload
            })
            iot.emit("MQTT_MESSAGE_" .. self.id)
        elseif event == "conack" then
            iot.emit("MQTT_CONNECT_" .. self.id)
            iot.emit("MQTT_PUBLISH_" .. self.id)

            -- 恢复订阅
            for filter, cnt in pairs(self.subs) do
                if cnt > 0 then
                    -- log.info("recovery subscribe", filter)
                    client:subscribe(filter)
                end
            end

            if self.options.on_connect then
                self.options.on_connect()
            end
        elseif event == "disconnect" then
            iot.emit("MQTT_DISCONNECT_" .. self.id)

            if self.options.on_disconnect then
                self.options.on_disconnect()
            end
        end
    end)

    -- 处理MQTT消息，主要是回调中可能有sys.wait，所以必须用task
    iot.start(function()
        while self.client do
            iot.wait("MQTT_MESSAGE_" .. self.id, 30000)

            -- 先从队列中取
            while #self.sub_queue > 0 do
                local m = table.remove(self.sub_queue, 1)
                -- 处理消息
                local ts = string.split(m.topic, "/")

                -- 直接抛出异常，方便查问题
                -- find_callback(self.sub_tree, ts, 1, m.topic, m.payload)

                -- 加入异常处理，避免异常崩溃
                local ret2, info = xpcall(find_callback, function(err)
                    return debug.traceback(err, 2)
                end, self.sub_tree, ts, 1, m.topic, m.payload)

                if not ret2 then
                    log.error(info)
                    iot.emit("error", info)
                end
            end
        end
        log.info("message handling task exit")
    end)

    -- 处理发送消息
    iot.start(function()
        while self.client do
            iot.wait("MQTT_PUBLISH_" .. self.id, 30000)

            -- 先从队列中取
            while self.client:ready() and #self.pub_queue > 0 do
                local m = table.remove(self.pub_queue, 1)
                self.client:publish(m.topic, m.payload, m.qos)
            end
        end
    end)

    -- 连接
    local ret = self.client:connect()
    if not ret then
        return false, "连接MQTT失败"
    end

    iot.wait("MQTT_CONNECT_" .. self.id)

    return true
end

-- 监听连接成功
function MqttClient:on_connect(cb)
    iot.on("MQTT_CONNECT_" .. self.id, cb)
end

-- 监听连接失败
function MqttClient:on_disconnect(cb)
    iot.on("MQTT_DISCONNECT_" .. self.id, cb)
end

--- 关闭平台（不太需要）
function MqttClient:close()
    if self.client then
        self.client:disconnect()
        self.client:close()
        self.client = nil
    end
end

--- 发布消息
-- @param topic string 主题
-- @param payload string|table|nil 数据，支持string,table
-- @param qos integer|nil 质量
-- @return integer 消息id
function MqttClient:publish(topic, payload, qos)
    if self.client == nil then
        return false, "客户端为空"
    end

    -- 太多消息，则不发送
    if #self.pub_queue > 50 then
        return false, "太多MQTT消息"
    end

    -- 转为json格式
    if type(payload) ~= "string" then
        local err
        payload, err = iot.json_encode(payload, "2f")
        if payload == nil then
            payload = "payload解析错误：" .. err
        end
    end
    log.info("publish", topic, payload, qos)

    -- return true, self.client:publish(topic, payload, qos)
    -- 异步发送消息，避免拥堵
    table.insert(self.pub_queue, {
        topic = topic,
        payload = payload,
        qos = qos
    })

    if self.client:ready() then
        iot.emit("MQTT_PUBLISH_" .. self.id)
    end

    return true
end

--- 订阅（检查重复订阅，只添加回调）
-- @param filter string 主题
-- @param cb function 回调
function MqttClient:subscribe(filter, cb)
    log.info("subscribe", filter)

    -- 计数，避免重复订阅
    if not self.subs[filter] or self.subs[filter] <= 0 then
        if self.client then
            self.client:subscribe(filter)
        end
        self.subs[filter] = 1
    else
        self.subs[filter] = self.subs[filter] + 1
    end

    local fs = string.split(filter, "/")

    -- 创建树枝
    local sub = self.sub_tree
    for _, f in ipairs(fs) do
        local s = sub.children[f]
        if s == nil then
            s = {
                children = {},
                callbacks = {}
            }
            sub.children[f] = s
        end
        sub = s
    end

    -- 避免重复订阅
    for _, c in ipairs(sub.callbacks) do
        if c == cb then
            self.subs[filter] = self.subs[filter] - 1
            return
        end
    end

    -- 注册回调
    table.insert(sub.callbacks, cb)
end

--- 取消订阅（cb不为空，检查订阅，只有全部取消时，才取消。 cb为空，全取消）
-- @param filter string 主题
-- @param cb function|nil 回调
function MqttClient:unsubscribe(filter, cb)
    log.info("unsubscribe", filter)

    local fs = string.split(filter, "/")

    -- 查树枝
    local sub = self.sub_tree
    for _, f in ipairs(fs) do
        local s = sub.children[f]
        if s == nil then
            return -- 找不到了
        end
        sub = s
    end

    local cnt = 0

    -- 删除回调
    if #sub.callbacks == 1 or cb == nil then
        sub.callbacks = {}
    else
        for i, c in ipairs(sub.callbacks) do
            if c == cb then
                table.remove(sub.callbacks, i)
                cnt = cnt + 1
            end
        end
    end

    -- 取消订阅
    if self.subs[filter] ~= nil then
        if cb == nil then
            self.subs[filter] = 0
            if self.client then
                self.client:unsubscribe(filter)
            end
        elseif cnt > 0 then
            self.subs[filter] = self.subs[filter] - cnt
            if self.subs[filter] <= 0 then
                if self.client then
                    self.client:unsubscribe(filter)
                end
            end
        end
    end
end

--- 云服务器连接状态
-- @return boolean 状态
function MqttClient:ready()
    if self.client then
        return self.client:ready()
    end
    return false
end

return MqttClient
