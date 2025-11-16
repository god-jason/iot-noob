local cloud = {}
local tag = "cloud"

local configs = require("configs")
local gateway = require("gateway")
local binary = require("binary")

local config = {
    broker = "",
    port = 1883,
    device_id = "",
    collect_cycle = 10, -- 采集周期 分钟
    upload_cycle = 10, -- 上传周期 分钟
}

--- 平台连接
local client = nil

local function auth()
    local ret, headers, body = http.request("POST", "https://dm-dev.crcgas.com/v2/iot/devices/edge/auth", {
        ["Content-Type"] = "application/json"
    }, json.encode({
        imei = mobile.imei(),
        iccid = mobile.iccid()
    })).wait()
    log.info("crcgas auth response ", ret, json.encode(headers), body)

end

local function create_pack(type, param)
    return {
        mid = os.time(),
        type = type,
        timestamp = os.time() .. "000", -- 时间戳 毫秒
        deviceId = config.device_id,
        param = param
    }
end

-- 设备接入接口 /v2/#{deviceId}/device/up/request
local function device_request()
    client:publish("/v2/" .. config.device_id .. "/device/up/request", create_pack("DEVICE_ACCESS", {
        softwareVersion = VERSION,
        collectCycle = 10, -- 采集周期 分钟
        uploadCycle = 10 -- 上传周期 分钟
    }))
end

-- 设备接入返回 /v2/#{deviceId}/device/down/reply
local function on_device_reply(topic, data)
    -- data.code 2000

end

-- 新增子设备接口 /v2/#{deviceId}/subDevice/up/request 
local function create_sub_device()
    client:publish("/v2/" .. config.device_id .. "/subDevice/up/request", create_pack("SUB_DEVICE_ADD", {
        subDeviceAddr = "",
        subDeviceName = "",
        subDeviceCategory = ""
    }))
end

-- 新增子设备返回 /v2/#{deviceId}/subDevice/down/reply
local function on_sub_device_reply(topic, data)
    -- data.param.subDeviceId
end

-- 数据上报接口 /v2/#{deviceId}/data/up/collect
local function report_data(device_id, values)
    local data = {}
    local param = {{
        subDeviceAddr = device_id,
        collectTime = os.time() * 1000,
        data = data,
    }}

    --table k->{value->any, time->int}
    for k, v in pairs(values) do
      table.insert(data, {
        name = k,
        value = v.value
      })  
    end
    
    client:publish("/v2/" .. config.device_id .. "/data/up/collect", create_pack("DATA_COLLECT", param))
end

-- 数据上报返回 /v2/#{deviceId}/data/down/reply
local function on_report_data_reply(topic, data)

end

-- 事件上报接口 /v2/#{deviceId}/data/up/event
local function report_event(device_id, type, code, status, data)
    client:publish("/v2/" .. config.device_id .. "/data/up/event", create_pack("DATA_EVENT", {{
        subDeviceAddr = device_id,
        eventTime = os.time() * 1000,
        eventType = type, -- 1故障 2告警 3离线 4其他
        eventCode = code, -- 错误码
        eventStatus = status, -- 0开始 1中 2结束
        data = data
    }}))
end

-- 指令下发接口 /v2/#{deviceId}/cmd/down/request
local function on_cmd_request(topic, data)
    -- data.param.subDeviceAddr
    -- data.param.cmdType 0读取 1写入 2执行
    -- data.param.cmd = {key=value}

end

-- 指令下发返回接口 /v2/#{deviceId}/cmd/up/reply
local function cmd_response(device_id, cmdType, status, data)
    client:publish("/v2/" .. config.device_id .. "/cmd/up/reply", create_pack("CMD_SEND", {{
        subDeviceAddr = device_id,
        cmdType = cmdType, -- 0读取 1写入 2执行
        status = status, -- 0成功 1失败 2指令过长
        data = data
        -- {{
        --     ["key"] = "", -- 原始值
        --     status = 0 -- 0成功 1失败 2不支持
        -- }}
    }}))
end

-- 监听 固件升级指令下发  /v2/{deviceId}/upgrade/down/request
local function on_upgrade_request(topic, data)
    -- data.param.taskInfoId 升级任务ID
    -- data.param.packageSize 升级包总大小
    -- data.param.packageName 升级包名称
    -- data.param.protocol 升级协议(分为mqtt,https)
    -- data.param.upgradeType 升级类型（分为fota,sota）
    -- data.param.md5 升级包md5码
    -- data.param.url 固件包下载地址
end

-- 设备请求升级包分片下载 v2/{deviceId}/upgrade/up/download/request
local function upgrade_download(offset, size, taskId)
    client:publish("/v2/" .. config.device_id .. "/cmd/up/reply", create_pack("UPGRADE_DOWNLOAD", {{
        offset = offset,
        buffSize = size,
        taskInfoId = taskId,
    }}))    
end

-- 平台返回升级包分片数据 /v2/{deviceId}/upgrade/down/download/reply
local function on_upgrade_reply(topic, data)
    -- mid 8byte
    -- offset 2byte
    -- buffSize 2byte
    -- data ...
    -- crc 4byte
end

-- 固件升级状态上报平台 /v2/#{deviceId}/upgrade/up/status
local function report_upgrade_status(status, taskId)
    client:publish("/v2/" .. config.device_id .. "/upgrade/up/status", create_pack("UPGRADE_STATUS", {{
        status = status, -- 200下载成功 201下载失败 300升级成功 301升级失败
        taskInfoId = taskId,
    }}))
end

-- 设备下线申请接口 /v2/#{deviceId}/device/offline/up/request
local function offline_request()
    client:publish("/v2/" .. config.device_id .. "/device/offline/up/request", create_pack("DEVICE_OFFLINE", {}))
end

-- 下线申请返回接口 /v2/#{deviceId}/device/offline/down/reply
local function on_offline_reply(topic, data)
    -- data.param.respond 0同意下线 1不同意下线 有任务未完成
end


local topics = {}

-- 解析JSON
local function parse_json(callback)
    return function(topic, payload)
        log.info(tag, "topic", topic)
        local data, err = iot.json_decode(payload)
        if err then
            log.info(tag, "decode", payload, err)
            return
        end
        callback(topic, data)
    end
end

--- 打开平台
function cloud.open()
    local ret, data = configs.load("cloud")
    if not ret then
        return false
    end
    config = data
    log.info(tag, "cloud config", iot.json_encode(config))

    -- oneNet鉴权
    

    client = iot.mqtt({
        host = config.broker,
        port = config.port,
        clientid = clientid,
        username = username,
        password = password
    })

    -- 订阅主题
    client:subscribe("/v2/"..config.device_id.."/device/down/reply", parse_json(on_device_reply))
    client:subscribe("/v2/"..config.device_id.."/subDevice/down/reply", parse_json(on_sub_device_reply))
    client:subscribe("/v2/"..config.device_id.."/data/down/reply", parse_json(on_report_data_reply))
    client:subscribe("/v2/"..config.device_id.."/cmd/down/request", parse_json(on_cmd_request))
    client:subscribe("/v2/"..config.device_id.."/upgrade/down/reply", parse_json(on_upgrade_request))
    client:subscribe("/v2/"..config.device_id.."/upgrade/down/download/reply", on_upgrade_reply)

    return client:open()
end

function cloud.task()

    -- 等待网络就绪
    iot.wait("IP_READY")

    cloud.open()

    log.info(tag, "cloud broker connected")

    -- iot.setInterval(report_all, 1000 * 60 * 60) -- 一小时全部传一次

    while true do

        local devices = gateway.get_all_device_instanse();

        for id, dev in pairs(devices) do

            -- 1 设备上线
            

            -- 2 上传数据
            report_data(id, dev:values())

        end

        iot.sleep(60 * 1000 * (config.upload_cycle or 1)) -- 上传周期
    end

end

iot.start(cloud.task)

return cloud
