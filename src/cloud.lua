--- 云平台
--- @module "cloud"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "cloud"
local cloud = {}

local configs = require("configs")

local default_config = {
    id = "test",
    host = "git.zgwit.com",
    port = 1883,
    clienid = "test",
    username = "",
    password = ""
    -- will = { -- 遗嘱消息
    --     topic = mobile.getImei().."/will",
    --     payload = "",
    -- }
}

local config = {}

-- mqtt连接
local client = nil


-- 订阅历史
local subs = {}
-- 订阅树
local sub_tree = {
    children = {}, -- topic->sub_tree
    callbacks = {}
}

--- 查询订阅树
local function find_callback(node, topics, topic, payload)
    -- 叶子节点，执行回调
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

-- 事件响应（优先执行绝对订阅，+#）
local function on_message(topic, payload)
    local ts = string.split(topic, "/")
    find_callback(sub_tree, ts, topic, payload)
end

--- mqtt事件处理
local function on_event(client, event, data, payload)
    -- 用户自定义代码
    --log.info(tag, "event", event, client, data, payload)
    if event == "conack" then
        -- 联上了
        sys.publish("MQTT_CONACK")
        -- client:subscribe(sub_topic)--单主题订阅
        -- client:subscribe({[topic1]=1,[topic2]=1,[topic3]=1})--多主题订阅

        -- 恢复订阅
        for filter, cnt in pairs(subs) do
            client:subscribe(filter)
        end
    elseif event == "recv" then
        --log.info(tag, "topic", data, "payload", payload)
        -- sys.publish("mqtt_payload", data, payload)
        on_message(data, payload)
    elseif event == "sent" then
        --log.info(tag, "sent", "pkgid", data)
    elseif event == "disconnect" then
        -- 非自动重连时,按需重启mqttc
        -- client:connect()
    end
end

-- 平台初始化，加载配置
function cloud.init()
    local ret

    -- 加载配置
    ret, config = configs.load(tag)
    if not ret then
        -- 使用默认
        config = default_config
        -- 默认使用imei号作为网关ID
        config.id = mobile.imei()
        config.clienid = mobile.imei()
    end

    log.info(tag, "init")
end

--- 获取ID
--- @return string ID号，一般是IMEI
function cloud.id()
    return config.id
end

---打开平台
---@return boolean 成本与否
function cloud.open()
    if mqtt == nil then
        log.info(tag, "bsp does not have mqtt lib")
        return false
    end

    client = mqtt.create(nil, config.host, config.port)
    if client == nil then
        log.info(tag, "create client failed")
        return false
    end

    client:auth(config.clienid, config.username, config.password) -- 鉴权
    -- client:keepalive(240) -- 默认值240s
    client:autoreconn(true, 3000)                                 -- 自动重连机制

    if config.will ~= nil then
        client:will(config.will.topic, config.will.payload)
    end

    -- 注册回调
    client:on(on_event)

    -- 连接
    return client:connect()
end

--- 关闭平台（不太需要）
function cloud.close()
    client:close()
    --client = nil
end

--- 发布消息
---@param topic string 主题
---@param payload string|table 数据，支持string,table
---@param qos integer|nil 质量
---@return integer 消息id
function cloud.publish(topic, payload, qos)
    -- 转为json格式
    if type(payload) ~= "string" then
        payload = json.encode(payload)
    end
    return client:publish(topic, payload, qos)
end

--- 订阅（检查重复订阅，只添加回调）
--- @param filter string 主题
--- @param cb function 回调
function cloud.subscribe(filter, cb)
    if not subs[filter] then
        subs[filter] = 1
    else
        subs[filter] = subs[filter] + 1
    end

    local fs = string.split(filter, "/")

    -- 创建树枝
    local sub = sub_tree
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
    if #sub.callbacks == 0 then
        client:subscribe(filter)
    end

    table.insert(sub.callbacks, cb)
end

--- 取消订阅（cb不为空，检查订阅，只有全部取消时，才取消。 cb为空，全取消）
--- @param filter string 主题
--- @param cb function|nil 回调
function cloud.unsubscribe(filter, cb)
    if subs[filter] then
        subs[filter] = subs[filter] - 1
    end

    -- 取消全部订阅
    if cb == nil then
        client:unsubscribe(filter)
        return
    end

    local fs = string.split(filter, "/")

    -- 创建树枝
    local sub = sub_tree
    for _, f in ipairs(fs) do
        local s = sub.children[f]
        if s == nil then
            return
        end
        sub = s
    end

    -- 删除回调
    for i, c in ipairs(sub.callbacks) do
        if c == cb then
            table.remove(sub.callbacks, i)
        end
    end
    if #sub.callbacks == 1 then
        client:unsubscribe(filter)
    end
end

--- 云服务器连接状态
--- @return boolean 状态
function cloud.isReady()
    return client:ready()
end

return cloud
