local cloud = {}
local tag = "cloud"

local configs = require("configs")
local gateway = require("gateway")
local binary = require("binary")

local increment = 0

local function get_increment()
    increment = increment + 1
    if increment > 999999 then
        increment = 1
    end
    return tostring(increment)
end

local function create_package(params)
    return {
        id = get_increment(),
        version = "1.0",
        params = params
    }
end

--- 平台连接
local client = nil

local config = {
    broker = "",
    port = 1883,
    product_id = "",
    device_name = "",
    device_key = "",
    cycle_upload = 10 -- 默认10分钟
}

local topics = {}

local info = {
    hwVersion = {
        value = "1.0.0"
    },
    swVersion = {
        value = _G.VERSION
    },
    network = {
        value = 0
    }, -- 默认移动
    radio = {
        value = mobile.csq()
    },
    cycleUpload = {
        value = config.cycle_upload
    },
    timeCalibration = {
        value = os.date("%Y%m%d%H%M%S", os.time())
    },
    timeAcqu = {
        value = os.date("%Y%m%d%H%M%S", os.time())
    },
    IMEI = {
        value = mobile.imei()
    },
    IMSI = {
        value = mobile.imsi()
    },
    ICCID = {
        value = mobile.iccid()
    }
}

local function property_post(values)
    local payload = create_package(values)
    client:publish(topics.property_post, payload)
end

local function event_post(name, args)
    local data = create_package({
        [name] = {
            value = args,
            time = os.time()
        }
    })
    client:publish(topics.event_post, data)
end

local function on_service_invoke(_, payload)
    log.info(tag, "on_service_invoke", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end
    data.success = false
    data.msg = "不支持"

    client:publish(topics.service_invoke_reply, payload)
end

local function on_property_get(_, payload)
    log.info(tag, "on_property_get", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end

    data.success = false
    data.msg = "不支持"
    client:publish(topics.property_get_reply, data)
end

local function on_property_set(_, payload)
    log.info(tag, "on_property_set", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end

    for key, value in pairs(data.params) do
        log.info(tag, "set property", key, value)

        -- 时间校准
        if key == "timeCalibration" then
            local dt = binary.decodeHex(value)
            local tm = binary.decodeDatetimeBCD(dt)
            rtc.set(tm)
            -- TODO 数据更新到所有子设备中
        end
        -- 修改上传周期
        if key == "cycleUpload" then
            info.cycleUpload.value = value
            config.cycle_upload = value
            configs.save("cloud", config) -- 保存配置
        end
        -- 采集并上传
        if key == "report" and value == true then
            -- 上报网关信息
            info.radio.value = mobile.csq()
            info.timeCalibration.value = os.date("%Y%m%d%H%M%S", os.time())
            info.timeAcqu.value = os.date("%Y%m%d%H%M%S", os.time())
            property_post(info)
        end
    end
    data.code = 200
    data.success = true
    client:publish(topics.property_set_reply, data)
end

local function pack_post(id, product_id, values)

    local data = create_package({{
        identity = {
            productID = product_id,
            deviceName = id
        },
        properties = values
    }})
    client:publish(topics.pack_post, data)
end

-- local function history_post(id, product_id, values)
--     local data = create_package({{
--         identify = {
--             productID = product_id,
--             deviceName = id
--         },
--         properties = values
--         -- properties = {
--         --     key = {{
--         --         value = value,
--         --         time = time
--         --     },{
--         --         value = value,
--         --         time = time
--         --     },}
--         -- }
--     }})
--     client:publish(topics.history_post, data)
-- end

local function sub_login(id, product_id)
    local data = create_package({
        productID = product_id,
        deviceName = id
    })
    client:publish(topics.sub_login, data)
end

local function report_device(dev)
    local obj = {}
    local values = dev:values()
    local len = 0
    for k, v in pairs(values) do
        if k ~= "tempError" and k ~= "tempErrorType" then
            obj[k] = {
                value = v.value
            }
            len = len + 1
        end
    end

    -- 在线状态
    if dev.product_id == "wKMUGRBKVL" then
        obj.hmDeviceNum = {
            value = dev.address
        }
        obj.hmDeviceName = {
            value = dev.id
        }
        obj.hmProductId = {
            value = dev.product_id
        }
        obj.hmStatus = {
            value = (len == 0)
        }
        if values.tempError and values.tempError.value then
            if values.tempErrorType.value == 0 then
                obj.supplyTempAlarm = {
                    value = true
                }
                obj.returnTempAlarm = {
                    value = false
                }
            else
                obj.supplyTempAlarm = {
                    value = false
                }
                obj.returnTempAlarm = {
                    value = true
                }
            end
        else
            obj.supplyTempAlarm = {
                value = false
            }
            obj.returnTempAlarm = {
                value = false
            }
        end
    end
    if dev.product_id == "aAHGgGOpNy" or dev.product_id == "Sw2UyvE700" then
        obj.valveDeviceNum = {
            value = dev.address
        }
        obj.valveDeviceName = {
            value = dev.id
        }
        obj.valveProductId = {
            value = dev.product_id
        }
        obj.valveStatus = {
            value = (len == 0)
        }
        -- 控制模式
        if obj.controlMode then
            obj.controlMode = {
                value = obj.controlMode.value == 1
            }
        end
    end

    -- 数据更新时间 TODO 应该在dev._updated
    obj.timeAcqu = {
        value = os.date("%Y%m%d%H%M%S", os.time())
    }

    pack_post(dev.id, dev.product_id, obj)
end

-- local function sub_logout(id, product_id)
--     local data = create_package({
--         productID = product_id,
--         deviceName = id
--     })
--     client:publish(topics.sub_logout, data)
-- end

local function on_sub_property_get(_, payload)
    log.info(tag, "on_sub_property_get", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end

    local id = data.params.deviceName
    local dev = gateway.get_device_instanse(id)
    if not dev then
        data.success = false
        data.msg = "找不到设备"
        data.code = 201
        client:publish(topics.sub_property_get_reply, data)
        return
    end

    data.code = 200
    data.data = {}
    for _, key in ipairs(data.params) do
        data.data[key] = dev.get(key)
    end

    client:publish(topics.sub_property_get_reply, data)
end

local function on_sub_property_set(_, payload)
    log.info(tag, "on_sub_property_set", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end

    local id = data.params.deviceName
    local dev = gateway.get_device_instanse(id)
    if not dev then
        data.success = false
        data.msg = "找不到设备"
        data.code = 201
        client:publish(topics.sub_property_set_reply, data)
        return
    end

    for key, value in pairs(data.params.params) do
        dev:set(key, value)
        -- 开阀门 特例处理
        if key == "openControl" and dev.product_id == "aAHGgGOpNy" then
            dev:write("50", "16", "A017", string.char(value))
        end
        if key == "openControl" and dev.product_id == "Sw2UyvE700" then
            dev:write("55", "16", "A017", string.char(value))
        end
        -- 采集并上传
        if key == "report" and value == true then
            dev:poll()
            report_device(dev)
        end
    end

    data.code = 200
    client:publish(topics.sub_property_set_reply, data)
end

local function on_sub_service_invoke(_, payload)
    log.info(tag, "on_sub_service_invoke", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end

    data.success = false
    data.msg = "不支持"
    client:publish(topics.sub_service_invoke_reply, data)
end

-- local function sub_topo_add(id, product_id)
--     local data = create_package({
--         productID = product_id,
--         deviceName = id,
--         sasToken = "" -- TODO Token哪里来
--     })
--     client:publish(topics.sub_topo_add, data)
-- end

-- local function sub_topo_delete(id, product_id)
--     local data = create_package({
--         productID = product_id,
--         deviceName = id,
--         sasToken = ""
--     })
--     client:publish(topics.sub_topo_delete, data)
-- end

-- local function sub_topo_get()
--     local data = create_package({})
--     client:publish(topics.sub_topo_get, data)
-- end

-- local function on_sub_topo_get_reply(_, payload)
--     log.info(tag, "on_sub_topo_get_reply", payload)
--     local data, ret = iot.json_decode(payload)
--     if ret == 0 then
--         return
--     end
--     -- data.data : [{deviceName, productID}]
--     log.info(tag, data, ret)
-- end

local function on_sub_topo_change(_, payload)
    log.info(tag, "on_sub_topo_change", payload)
    local data, ret = iot.json_decode(payload)
    if ret == 0 then
        return
    end
    -- TODO 子设备关系变化
    log.info(tag, data, ret)
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
    local clientid, username, password = iotauth.onenet(config.product_id, config.device_name, config.device_key, nil,
        nil, nil, "products/" .. config.product_id .. "/devices/" .. config.device_name)
    log.info(tag, "auth result", clientid, username, password)

    client = iot.mqtt({
        host = config.broker,
        port = config.port,
        clientid = clientid,
        username = username,
        password = password
    })

    -- 创建主题
    local topic_prefix = "$sys/" .. config.product_id .. "/" .. config.device_name .. "/thing/"
    topics = {
        -- 网关消息
        property_post = topic_prefix .. "property/post", -- 发布 属性
        property_post_reply = topic_prefix .. "property/post/reply",
        event_post = topic_prefix .. "event/post", -- 发布 事件
        event_post_reply = topic_prefix .. "event/post/reply",
        property_get = topic_prefix .. "property/get", -- 订阅 查询属性
        property_get_reply = topic_prefix .. "property/get_reply",
        property_set = topic_prefix .. "property/set", -- 订阅 设置属性
        property_set_reply = topic_prefix .. "property/set_reply",
        service_invoke = topic_prefix .. "service/+/invoke", -- 订阅 执行服务
        service_invoke_reply = topic_prefix .. "service/{id}/invoke_reply",

        -- 期望值
        desired_get = topic_prefix .. "property/desired/get", -- 发布 期望值
        desired_get_reply = topic_prefix .. "property/desired/get/reply",
        desired_delete = topic_prefix .. "property/desired/delete", -- 发布 删除期望值
        desired_delete_reply = topic_prefix .. "property/desired/delete/reply",

        -- 打包上传
        pack_post = topic_prefix .. "pack/post", -- 发布 打包上传属性
        pack_post_reply = topic_prefix .. "pack/post/reply",
        history_post = topic_prefix .. "history/post", -- 发布 上传历史数据
        history_post_reply = topic_prefix .. "history/post/reply",

        -- 子设备
        sub_login = topic_prefix .. "sub/login", -- 发布 子设备上线
        sub_login_reply = topic_prefix .. "sub/login/reply",
        sub_logout = topic_prefix .. "sub/logout", -- 发布 子设备下线
        sub_logout_reply = topic_prefix .. "sub/logout/reply",
        sub_property_get = topic_prefix .. "sub/property/get", -- 订阅 查询属性
        sub_property_get_reply = topic_prefix .. "sub/property/get_reply",
        sub_property_set = topic_prefix .. "sub/property/set", -- 订阅 设置属性
        sub_property_set_reply = topic_prefix .. "sub/property/set_reply",
        sub_service_invoke = topic_prefix .. "sub/service/invoke", -- 订阅 执行服务
        sub_service_invoke_reply = topic_prefix .. "sub/service/invoke_reply",
        sub_topo_add = topic_prefix .. "sub/topo/add", -- 发布 添加子设备
        sub_topo_add_reply = topic_prefix .. "sub/topo/add/reply",
        sub_topo_delete = topic_prefix .. "sub/topo/delete", -- 发布 删除子设备
        sub_topo_delete_reply = topic_prefix .. "sub/topo/delete/reply",
        sub_topo_get = topic_prefix .. "sub/topo/get", -- 发布 查询子设备
        sub_topo_get_reply = topic_prefix .. "sub/topo/get/reply",
        sub_topo_get_result = topic_prefix .. "sub/topo/get/result", -- 发布 网关同步结果
        sub_topo_change = topic_prefix .. "sub/topo/change", -- 订阅 通知子设备变化
        sub_topo_change_reply = topic_prefix .. "sub/topo/change/reply"
    }
    -- 订阅全部主题
    client:subscribe(topics.property_get, on_property_get)
    client:subscribe(topics.property_set, on_property_set)
    -- client:subscribe(topics.service_invoke, on_service_invoke)
    client:subscribe(topics.sub_property_get, on_sub_property_get)
    client:subscribe(topics.sub_property_set, on_sub_property_set)
    -- client:subscribe(topics.sub_service_invoke, on_sub_service_invoke)
    -- client:subscribe(topics.sub_topo_change, on_sub_topo_change)

    -- 订阅回复
    client:subscribe(topics.property_post_reply, function(_, payload)
        log.info(tag, "property_post_reply", payload)
    end)
    client:subscribe(topics.pack_post_reply, function(_, payload)
        log.info(tag, "pack_post_reply", payload)
    end)

    return client:open()
end

function cloud.task()

    -- 等待网络就绪
    iot.wait("IP_READY")

    cloud.open()

    log.info(tag, "cloud broker connected")

    -- iot.setInterval(report_all, 1000 * 60 * 60) -- 一小时全部传一次

    while true do

        -- 上报网关信息
        info.radio.value = mobile.csq()
        info.timeCalibration.value = os.date("%Y%m%d%H%M%S", os.time())
        info.timeAcqu.value = os.date("%Y%m%d%H%M%S", os.time())
        property_post(info)

        local devices = gateway.get_all_device_instanse();

        for id, dev in pairs(devices) do

            -- 1 设备上线
            if not dev._registered then
                sub_login(id, dev.product_id)
                dev._registered = true
            end

            -- 2 定时上传
            -- local values = dev:modified_values()
            -- log.info(tag, "cloud report", id, iot.json_encode(values))

            -- local has = false
            -- for _, _ in pairs(values) do
            --     has = true
            -- end
            -- if has then
            --     pack_post(id, dev.product_id, values)
            -- end

            report_device(dev)
        end

        iot.sleep(60 * 1000 * (config.cycle_upload or 1)) -- 上传周期
    end

end

iot.start(cloud.task)

return cloud
