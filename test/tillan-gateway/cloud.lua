local cloud = {}

local client = nil

function cloud.init()
    client = mqtt.create(nil, "36.151.72.58", 1883)

    client:auth(mobile.imei(), "", "")

    client:autoreconn(true)

    return client:connect()
end

function cloud.publish(topic, payload, qos)
    if type(payload) ~= "string" then
        local err
        payload, err = iot.json_encode(payload, "2f")
        -- payload, err = iot.json_encode(payload)
        if payload == nil then
            payload = "payload json encode error:" .. err
        end
    end
    return client:publish(topic, payload, qos)
end

return cloud
