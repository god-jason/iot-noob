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

local mqtt_client = nil

local function mqtt_handle(client, event, data, payload)
    -- 用户自定义代码
    log.info(tag, "event", event, client, data, payload)
    if event == "conack" then
        -- 联上了
        -- sys.publish("mqtt_conack")
        -- client:subscribe(sub_topic)--单主题订阅
        -- mqtt_client:subscribe({[topic1]=1,[topic2]=1,[topic3]=1})--多主题订阅
    elseif event == "recv" then
        log.info(tag, "topic", data, "payload", payload)
        -- sys.publish("mqtt_payload", data, payload)
        mqtt_message(data, payload)
    elseif event == "sent" then
        log.info(tag, "sent", "pkgid", data)
    elseif event == "disconnect" then
        -- 非自动重连时,按需重启mqttc
        -- mqtt_client:connect()
    end
end

local function mqtt_message(topic, payload)
    -- 查找订阅树
end

function mqtt_open()
    if mqtt == nil then
        log.info(tag, "bsp does not have mqtt lib")
        return
    end

    mqtt_client = mqtt.create(nil, mqtt.host, mqtt.port)
    if mqtt_client == nil then
        log.info(tag, "create client failed")
        return
    end

    mqtt_client:auth(mqtt.clienid, mqtt.username, mqtt.password) -- 鉴权
    -- mqtt_client:keepalive(240) -- 默认值240s
    mqtt_client:autoreconn(true, 3000) -- 自动重连机制

    if config.will ~= nil then
        mqtt_client:will(config.will.topic, config.will.payload)
    end

    mqtt_client:connect()
end

function mqtt_close()
    mqtt_client:close()
    mqtt_client = nil
end

function mqtt_publish(topic, payload, qos)
    return mqtt_client:publish(topic, payload, qos)
end

function mqtt_subscribe(filter, cb)
    mqtt_client:subscribe(filter)

end

function unsubscribe(topic, cb)
    mqtt_client:subscribe(filter)
end

function ready()
    return mqtt_client:ready()
end
