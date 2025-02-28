local tag = "MQTT"

local config = {
    host = "iot.zgwit.com",
    port = 1883,
    clienid = mobile.getImei(),
    username = "",
    password = ""
    -- will = { -- 遗嘱消息
    --     topic = mobile.getImei().."/will",
    --     payload = "",
    -- }
}

local client = nil

local sub_tree = {
    children = {}, -- topic->sub_tree
    callbacks = {}
}

local function find_callback(node, topics, topic, payload)
    --叶子节点，执行回调
    if #topics == 0 then
        for i, cb in ipairs(sub.callbacks) do
            cb(topic, payload)
        end
        return
    end

    local sub = node.children["#"]
    if sub ~= nil then
        find_callback(node, {}, topic, payload)
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

-- 查找订阅树（bug，优先执行绝对订阅，+#）
local function on_message(topic, payload)
    local ts = string.split(topic, "/")
    find_callback(sub_tree, ts, topic, payload)
end

local function on_event(client, event, data, payload)
    -- 用户自定义代码
    log.info(tag, "event", event, client, data, payload)
    if event == "conack" then
        -- 联上了
        sys.publish("MQTT_CONACK")
        -- client:subscribe(sub_topic)--单主题订阅
        -- client:subscribe({[topic1]=1,[topic2]=1,[topic3]=1})--多主题订阅
    elseif event == "recv" then
        log.info(tag, "topic", data, "payload", payload)
        -- sys.publish("mqtt_payload", data, payload)
        on_message(data, payload)
    elseif event == "sent" then
        log.info(tag, "sent", "pkgid", data)
    elseif event == "disconnect" then
        -- 非自动重连时,按需重启mqttc
        -- client:connect()
    end
end


function init()
    if mqtt == nil then
        log.info(tag, "bsp does not have mqtt lib")
        return
    end

    client = mqtt.create(nil, mqtt.host, mqtt.port)
    if client == nil then
        log.info(tag, "create client failed")
        return
    end

    client:auth(mqtt.clienid, mqtt.username, mqtt.password) -- 鉴权
    -- client:keepalive(240) -- 默认值240s
    client:autoreconn(true, 3000)                           -- 自动重连机制

    if config.will ~= nil then
        client:will(config.will.topic, config.will.payload)
    end

    -- 注册回调
    client:on(on_event)

    -- 连接
    return client:connect()
end

function close()
    client:close()
    client = nil
end

function publish(topic, payload, qos)
    return client:publish(topic, payload, qos)
end

-- 订阅（检查重复订阅，只添加回调）
function subscribe(filter, cb)

    local fs = string.split(filter, "/")

    --创建树枝
    local sub = sub_tree
    for _, f in ipairs(fs) do
        local s = sub.children[f]
        if s == nil then
            s = { children = {}, callbacks = {} }
            sub.children[f] = s
        end
        sub = s
    end

    --注册回调
    if #sub.callbacks == 0 then
        client:subscribe(filter)        
    end

    table.insert(sub.callbacks, cb)
end

-- 取消订阅（cb不为空，检查订阅，只有全部取消时，才取消。 cb为空，全取消）
function unsubscribe(filter, cb)

    -- 取消全部订阅
    if cb == nil then
        client:unsubscribe(filter)
        return
    end

    local fs = string.split(filter, "/")

    --创建树枝
    local sub = sub_tree
    for _, f in ipairs(fs) do
        local s = sub.children[f]
        if s == nil then
            return
        end
        sub = s
    end

    --删除回调
    for i, c in ipairs(sub.callbacks) do
        if c == cb then
            table.remove(sub.callbacks, i)
        end
    end
    if #sub.callbacks == 1 then
        client:unsubscribe(filter)
    end
end

function isReady()
    return client:ready()
end
