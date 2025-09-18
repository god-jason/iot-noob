local cloud = {}
local tag = "cloud"

local configs = require("configs")
local MqttClient = require("mqtt_client")

--- 平台连接
local client = nil

local config = {
    broker = "",
    port = 1883,
    product_id = "",
    device_name = "",
    device_key = ""
}

local topics = {}

--- 打开平台
function cloud.open()
    local ret, data = configs.load("cloud")
    if not ret then
        return false
    end
    config = data

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
        service_invoke = topic_prefix .. "service/{id}/invoke", -- 订阅 执行服务
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

    local client_id, username, password = iotauth.onenet(config.product_id, config.device_name, config.device_key)


end

function cloud.connect()

end

return cloud
