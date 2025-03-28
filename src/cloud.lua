--- 云平台
--- @module "cloud"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.01.20
local tag = "cloud"
local cloud = {}

local configs = require("configs")

local default_options = {
    id = mobile.imei(),
    host = "git.zgwit.com",
    port = 1883,
    clienid = mobile.imei(),
    username = "",
    password = ""
    -- will = { -- 遗嘱消息
    --     topic = mobile.getImei().."/will",
    --     payload = "",
    -- }
}

local options = {}

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
        for i, cb in ipairs(node.callbacks) do
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

-- 事件响应（优先执行绝对订阅，+#）
local function on_message(topic, payload)
    log.info(tag, "on_message", topic, payload)
    local ts = string.split(topic, "/")
    find_callback(sub_tree, ts, topic, payload)
end

--- mqtt事件处理
local function on_event(client, event, topic, payload)
    -- 用户自定义代码
    log.info(tag, "event", event, client, topic, payload)

    if event == "conack" then
        -- 联上了
        sys.publish("CLOUD_CONNECTED")
        -- client:subscribe(sub_topic)--单主题订阅
        -- client:subscribe({[topic1]=1,[topic2]=1,[topic3]=1})--多主题订阅

        -- 恢复订阅
        for filter, cnt in pairs(subs) do
            if cnt > 0 then
                log.info(tag, "recovery subscribe", filter)
                client:subscribe(filter)    
            end
        end
    elseif event == "recv" then
        -- log.info(tag, "topic", data, "payload", payload)
        sys.publish("CLOUD_MESSAGE", topic, payload)
        -- on_message(data, payload)
    elseif event == "sent" then
        -- log.info(tag, "sent", "pkgid", data)
    elseif event == "disconnect" then
        -- 非自动重连时,按需重启mqttc
        -- client:connect()
    end
end

-- 平台初始化，加载配置
function cloud.init()
    log.info(tag, "init")

    -- 加载配置
    -- options = opts or default_options
    options = configs.load_default(tag, default_options)

    -- 用IMEI号作为默认ID
    if not options.id or #options.id == 0 then
        options.id = mobile.imei()
    end
    if not options.clienid or #options.clienid == 0 then
        options.clienid = mobile.imei()
    end
end

--- 获取ID
--- @return string ID号，一般是IMEI
function cloud.id()
    return options.id
end

---打开平台
---@return boolean 成功与否
function cloud.open()
    if mqtt == nil then
        log.info(tag, "bsp does not have mqtt lib")
        return false
    end

    client = mqtt.create(nil, options.host, options.port)
    if client == nil then
        log.info(tag, "create client failed")
        return false
    end

    client:auth(options.clienid, options.username, options.password) -- 鉴权
    -- client:keepalive(240) -- 默认值240s
    client:autoreconn(true, 3000) -- 自动重连机制

    if options.will ~= nil then
        client:will(options.will.topic, options.will.payload)
    end

    -- 注册回调
    client:on(on_event)

    -- 处理MQTT消息，主要是回调中可能有sys.wait，所以必须用task
    sys.taskInit(function()
        while client do
            local ret, topic, payload = sys.waitUntil("CLOUD_MESSAGE", 30000)
            if ret then
                on_message(topic, payload)
            end
        end
    end)

    -- 连接
    return client:connect()
end

--- 关闭平台（不太需要）
function cloud.close()
    client:close()
    -- client = nil
end

--- 发布消息
---@param topic string 主题
---@param payload string|table|nil 数据，支持string,table
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
    log.info(tag, "subscribe", filter)

    -- 计数，避免重复订阅
    if not subs[filter] or subs[filter] <= 0 then
        client:subscribe(filter)
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
    table.insert(sub.callbacks, cb)
end

--- 取消订阅（cb不为空，检查订阅，只有全部取消时，才取消。 cb为空，全取消）
--- @param filter string 主题
--- @param cb function|nil 回调
function cloud.unsubscribe(filter, cb)
    log.info(tag, "subscribe", filter)

    -- 取消订阅
    if subs[filter] ~= nil then
        if cb == nil then
            client:unsubscribe(filter)
        else
            subs[filter] = subs[filter] - 1
            if subs[filter] <= 0 then
                client:unsubscribe(filter)
            end
        end
    end

    local fs = string.split(filter, "/")

    -- 创建树枝
    local sub = sub_tree
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
--- @return boolean 状态
function cloud.isReady()
    return client:ready()
end

return cloud
