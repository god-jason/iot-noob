--- 阿里云平台
--- @module "aliyun"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.18
--- 源码参考： https://docs.openluat.com/air780epm/luatos/app/iotcloud/aliiot/

local tag = "aliyun"

local aliyun = {}

local configs = require("configs")

local options = {
    instance_id = "",
    product_id = "",
    product_secret = "",
    device_name = ""
}

local client = nil -- mqtt客户端

local function aliyun_callback(cli, event, topic, payload)
    log.info(tag, "event", event, topic, payload)

    if event == "conack" then
        log.info(tag, "conack")
        -- todo 鉴权
        -- options:subscribe("/ota/device/upgrade/" .. options.product_id .. "/" .. options.device_name) -- 订阅ota主题
        -- options:publish("/ota/device/inform/" .. options.product_id .. "/" .. options.device_name,
        --     "{\"id\":1,\"params\":{\"version\":\"" .. _G.VERSION .. "\"}}") -- 上报ota版本信息
    elseif event == "recv" then
        if topic == "/ext/regnwl" or topic == "/ext/register" then
            fskv.set("aliyun_register", payload)
        end
    elseif event == "sent" then
        log.info(tag, "sent", "pkgid", topic)
    elseif event == "disconnect" then
        -- 非自动重连时,按需重启mqttc
        cli:connect()
    end
end

-- 阿里云自动注册
function aliyun.open(register)
    local random = math.random(1, 999)
    local data = "deviceName" .. options.device_name .. "productKey" .. options.product_id .. "random" .. random
    local mqttClientId = options.device_name .. "|securemode=" .. (register and "2" or "-2") .. ",authType=" ..
                             (register and "register" or "regnwl") .. ",random=" .. random .. ",signmethod=hmacsha1" ..
                             (options.instance_id and (",instanceId=" .. options.instance_id) or "") .. "|"
    local mqttUserName = options.device_name .. "&" .. options.product_id
    local mqttPassword = crypto.hmac_sha1(data, options.product_secret):lower()

    client = mqtt.create(nil, options.host, options.port, true)
    client:auth(mqttClientId, mqttUserName, mqttPassword)
    client:on(aliyun_callback)
    client:connect()
end

function aliyun.init()
    log.info(tag, "init")

    local ret
    ret, options = configs.load(tag)
    if not ret then
        return false
    end

    if options.product_secret then -- 有 product_secret 说明是动态注册(一型一密)
        local data = fskv.get("aliyun_register")

        if data.deviceSecret then -- 一型一密(预注册)
            options.client_id, options.user_name, options.password =
                iotauth.aliyun(options.product_id, options.device_name, data.deviceSecret, options.method)
        else -- 一型一密(免预注册)
            options.client_id = data.clientId .. "|securemode=-2,authType=connwl|"
            options.user_name = options.device_name .. "&" .. options.product_id
            options.password = data.deviceToken
        end
        options.port = 1883
    else -- 否则为非动态注册(一机一密)
        if options.device_secret or options.key then -- 密钥认证
            options.device_secret = options.device_secret or options.key
            options.port = 1883
            options.client_id, options.user_name, options.password =
                iotauth.aliyun(options.product_id, options.device_name, options.device_secret, options.method)
            -- elseif connect_config.tls then                   -- 证书认证
            --     options.ip = 443
            --     options.isssl = true
            --     options.ca_file = {client_cert = connect_config.tls.client_cert}
            --     options.client_id,options.user_name =
            -- iotauth.aliyun(options.product_id,options.device_name,"",options.method,nil,true)
        else -- 密钥证书都没有
            return false
        end
    end

    if not options.host then
        options.host = (options.instance_id and (options.instance_id .. ".mqtt.iothub.aliyuncs.com")) or
                           options.product_id .. ".iot-as-mqtt.cn-shanghai.aliyuncs.com"
    end

    return true
end

--- 发布消息
---@param topic string 主题
---@param payload string|table|nil 数据，支持string,table
---@param qos integer|nil 质量
---@return integer 消息id
function aliyun.publish(topic, payload, qos)
    -- 转为json格式
    if type(payload) ~= "string" then
        payload = json.encode(payload)
    end
    return client:publish(topic, payload, qos)
end

local increment = 1

-- 上传设备属性
sys.subscribe("DEVICE_VALUES", function(dev, values)
    log.info(tag, dev, values)

    local topic = "/sys/" .. options.product_id .. "/" .. options.device_name .. "thing/event/property/post"
    local value = {
        id = tostring(increment),
        version = "1.0",
        sys = {
            ack = 0
        },
        params = values,
        method = "thing.event.property.post"
    }
    increment = increment + 1
    aliyun.publish(topic, value)
end)

return aliyun
