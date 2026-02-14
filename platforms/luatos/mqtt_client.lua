--- MQTT封装
-- @module mqtt_client
local MqttClient = {}
MqttClient.__index = MqttClient

local tag = "MqttClient"

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
    return client
end

--- 查询订阅树
local function find_callback(node, topics, topic, payload)
    -- 叶子节点，执行回调
    if #topics == 0 then
        for _, cb in ipairs(node.callbacks) do
            cb(topic, payload)
        end
        return
    end

    local sub = node.children["#"]
    if sub ~= nil then
        find_callback(sub, {}, topic, payload)
    end

    local t = topics[1]
    table.remove(topics, 1)

    sub = node.children["+"]
    if sub ~= nil then
        find_callback(sub, topics, topic, payload)
    end

    sub = node.children[t]
    if sub ~= nil then
        find_callback(sub, topics, topic, payload)
    end
end

---打开平台
-- @return boolean 成功与否
function MqttClient:open()
    if mqtt == nil then
        log.error(tag, "bsp does not have mqtt lib")
        return false
    end

    self.client = mqtt.create(nil, self.options.host, self.options.port, self.options.ssl)
    if self.client == nil then
        log.error(tag, "create client failed")
        return false
    end

    -- 鉴权
    self.client:auth(self.options.clientid, self.options.username, self.options.password)

    self.client:keepalive(self.options.keepalive or 240) -- 默认值240s

    self.client:autoreconn(true, self.reconnect_timeout or 5000) -- 自动重连机制 ms

    if self.options.will ~= nil then
        self.client:will(self.options.will.topic, self.options.will.payload)
    end

    -- 注册回调
    self.client:on(function(client, event, topic, payload)
        -- log.info(tag, "event", event, client, topic, payload)
        if event == "recv" then
            iot.emit("MQTT_MESSAGE_" .. self.id, topic, payload)
        elseif event == "conack" then
            iot.emit("MQTT_CONNECT_" .. self.id)
            -- 恢复订阅
            for filter, cnt in pairs(self.subs) do
                if cnt > 0 then
                    -- log.info(tag, "recovery subscribe", filter)
                    client:subscribe(filter)
                end
            end
        elseif event == "disconnect" then
            iot.emit("MQTT_DISCONNECT_" .. self.id)
        end
    end)

    -- 处理MQTT消息，主要是回调中可能有sys.wait，所以必须用task
    iot.start(function()
        while self.client do
            local ret, topic, payload = iot.wait("MQTT_MESSAGE_" .. self.id, 30000)
            if ret then
                local ts = string.split(topic, "/")
                if RELEASE then
                    -- 加入异常处理，避免异常崩溃
                    local ret2, info = pcall(find_callback, self.sub_tree, ts, topic, payload)
                    if not ret2 then
                        iot.emit("error", info)
                    end
                else
                    find_callback(self.sub_tree, ts, topic, payload)
                end
            end
        end
        log.info(tag, "message handling task exit")
    end)

    -- 连接
    local ret = self.client:connect()
    if not ret then
        return false
    end

    iot.wait("MQTT_CONNECT_" .. self.id)

    return true
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
        return false, "publish failed, client is nil"
    end
    -- 转为json格式
    if type(payload) ~= "string" then
        local err
        payload, err = iot.json_encode(payload, "2f")
        if payload == nil then
            payload = "payload json encode error:" .. err
        end
    end
    log.info(tag, "publish", topic, payload, qos)
    return true, self.client:publish(topic, payload, qos)
end

--- 订阅（检查重复订阅，只添加回调）
-- @param filter string 主题
-- @param cb function 回调
function MqttClient:subscribe(filter, cb)
    log.info(tag, "subscribe", filter)

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

    -- 注册回调
    table.insert(sub.callbacks, cb)
end

--- 取消订阅（cb不为空，检查订阅，只有全部取消时，才取消。 cb为空，全取消）
-- @param filter string 主题
-- @param cb function|nil 回调
function MqttClient:unsubscribe(filter, cb)
    log.info(tag, "unsubscribe", filter)

    -- 取消订阅
    if self.subs[filter] ~= nil then
        if cb == nil then
            self.subs[filter] = 0
            self.client:unsubscribe(filter)
        else
            self.subs[filter] = self.subs[filter] - 1
            if self.subs[filter] <= 0 then
                self.client:unsubscribe(filter)
            end
        end
    end

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

    -- 删除回调
    if #sub.callbacks == 1 or cb == nil then
        sub.callbacks = {}
    else
        for i, c in ipairs(sub.callbacks) do
            if c == cb then
                table.remove(sub.callbacks, i)
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
