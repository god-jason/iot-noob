--- 腾讯云平台
--- @module "tencent"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.18
--- 源码参考： https://docs.openluat.com/air780epm/luatos/app/iotcloud/tencentiot/
local tag = "tencent"

local tencent = {}

local configs = require("configs")

local options = {
    instance_id = "",
    product_id = "",
    product_secret = "",
    device_name = ""
}

local client = nil -- mqtt客户端


-- 腾讯云自动注册
local function tencent_autoenrol(options)
    local deviceName = options.device_name
    local nonce = math.random(1,100)
    local timestamp = os.time()
    local data = "deviceName="..deviceName.."&nonce="..nonce.."&productId="..options.product_id.."&timestamp="..timestamp
    local hmac_sha1_data = crypto.hmac_sha1(data,options.product_secret):lower()
    local signature = crypto.base64_encode(hmac_sha1_data)
    local cloud_body = {
        deviceName=deviceName,
        nonce=nonce,
        productId=options.product_id,
        timestamp=timestamp,
        signature=signature,
    }
    local cloud_body_json = json.encode(cloud_body)
    local code, headers, body = http.request("POST","https://ap-guangzhou.gateway.tencentdevices.com/register/dev", 
            {["Content-Type"]="application/json;charset=UTF-8"},
            cloud_body_json
    ).wait()

    if code == 200 then
        local dat, result, errinfo = json.decode(body)
        if result then
            if dat.code==0 then
                local payload = crypto.cipher_decrypt("AES-128-CBC","ZERO",crypto.base64_decode(dat.payload),string.sub(options.product_secret,1,16),"0000000000000000")
                local payload = json.decode(payload)
                fskv.set("iotcloud_tencent", payload)
                if payload.encryptionType == 1 then     -- 证书认证
                    options.authentication = iotcloud_certificate
                elseif payload.encryptionType == 2 then -- 密钥认证
                    options.authentication = iotcloud_key
                end
                return true
            else
                log.info("http.post", code, headers, body)
                return false
            end
        end
    else
        log.info("http.post", code, headers, body)
        return false
    end
end


local function tencent_callback(client, event, topic, payload)
    log.info(tag, "event", event, client, topic, payload)

    if event == "conack" then
        -- options:subscribe("/ota/device/upgrade/" .. options.product_id .. "/" .. options.device_name) -- 订阅ota主题
        -- options:publish("/ota/device/inform/" .. options.product_id .. "/" .. options.device_name,
        --     "{\"id\":1,\"params\":{\"version\":\"" .. _G.VERSION .. "\"}}") -- 上报ota版本信息
    elseif event == "recv" then
        if topic == "/ext/regnwl" or topic == "/ext/register" then
            fskv.set("tencent_register", payload)
        end
    elseif event == "sent" then
        -- log.info(tag, "sent", "pkgid", data)
    elseif event == "disconnect" then
        -- 非自动重连时,按需重启mqttc
        client:connect()
    end
end

-- 自动注册
function tencent.open(register)
    local random = math.random(1, 999)
    local data = "deviceName" .. options.device_name .. "productKey" .. options.product_id .. "random" .. random
    local mqttClientId = options.device_name .. "|securemode=" .. (register and "2" or "-2") .. ",authType=" ..
                             (register and "register" or "regnwl") .. ",random=" .. random .. ",signmethod=hmacsha1" ..
                             (options.instance_id and (",instanceId=" .. options.instance_id) or "") .. "|"
    local mqttUserName = options.device_name .. "&" .. options.product_id
    local mqttPassword = crypto.hmac_sha1(data, options.product_secret):lower()

    client = mqtt.create(nil, options.host, options.port, true)
    client:auth(mqttClientId, mqttUserName, mqttPassword)
    client:on(tencent_callback)
    client:connect()
end

function tencent.init()
    log.info(tag, "init")

    local ret
    ret, options = configs.load(tag)
    if not ret then
        return false
    end

    if options.product_secret then -- 有product_secret说明是动态注册
        if not fskv.get("iotcloud_tencent") then
            if not tencent_autoenrol(options) then
                return false
            end
        end

        local data = fskv.get("iotcloud_tencent")
        -- print("payload",data.encryptionType,data.psk,data.clientCert,data.clientKey)
        if data.encryptionType == 1 then -- 证书认证
            options.ip = 8883
            options.isssl = true
            options.ca_file = {
                client_cert = data.clientCert,
                client_key = data.clientKey
            }
            options.client_id, options.user_name = iotauth.qcloud(options.product_id, options.device_name, "")
        elseif data.encryptionType == 2 then -- 密钥认证
            options.ip = 1883
            options.device_secret = data.psk
            options.client_id, options.user_name, options.password =
                iotauth.qcloud(options.product_id, options.device_name, options.device_secret, options.method)
        end
    else -- 否则为非动态注册
        if options.device_secret then -- 密钥认证
            options.ip = 1883
            options.client_id, options.user_name, options.password =
                iotauth.qcloud(options.product_id, options.device_name, options.device_secret, options.method)
        elseif options.tls then -- 证书认证
            options.ip = 8883
            options.isssl = true
            options.ca_file = {
                client_cert = options.tls.client_cert
            }
            options.client_id, options.user_name = iotauth.qcloud(options.product_id, options.device_name, "")
        else -- 密钥证书都没有
            return false
        end
    end

    options.host = options.host or options.product_id .. ".iotcloud.tencentdevices.com"

    return true
end

--- 发布消息
---@param topic string 主题
---@param payload string|table|nil 数据，支持string,table
---@param qos integer|nil 质量
---@return integer 消息id
function tencent.publish(topic, payload, qos)
    -- 转为json格式
    if type(payload) ~= "string" then
        payload = json.encode(payload)
    end
    return client:publish(topic, payload, qos)
end

local increment = 1

-- 上传设备属性
sys.subscribe("DEVICE_VALUES", function(dev, values)
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
    tencent.publish(topic, values)
end)

return tencent
