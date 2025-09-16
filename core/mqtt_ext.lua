--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- 连接相关
-- @module links
-- @class MQTT
local MQTT = {}

local tag = "MQTT"

-- 自增ID
local increment = 1

---创建实例
-- @param opts table
-- @return table
function MQTT:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = increment
    increment = increment + 1
    obj.options = opts -- 参数
    obj.client = nil -- MQTT连接
    obj.subs = {} -- 订阅历史
    obj.sub_tree = {
        children = {}, -- topic->sub_tree
        callbacks = {}
    } -- 订阅树
    return obj
end

--- 查询订阅树
local function find_callback(node, topics, topic, payload)
    -- 叶子节点，执行回调
    if #topics == 0 then
        for _, cb in ipairs(node.callbacks) do
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

---打开平台
-- @return boolean 成功与否
function MQTT:open()
    if mqtt == nil then
        log.error(tag, "bsp does not have mqtt lib")
        return false
    end

    self.client = mqtt.create(nil, self.options.host, self.options.port)
    if self.client == nil then
        log.error(tag, "create client failed")
        return false
    end

    self.client:auth(self.options.clienid, self.options.username, self.options.password) -- 鉴权
    -- client:keepalive(240) -- 默认值240s
    self.client:autoreconn(true, 3000) -- 自动重连机制

    if self.options.will ~= nil then
        self.client:will(self.options.will.topic, self.options.will.payload)
    end

    -- 注册回调
    self.client:on(function(client, event, topic, payload)
        -- log.info(tag, "event", event, client, topic, payload)
        if event == "recv" then
            sys.publish("MQTT_MESSAGE_" .. self.id, topic, payload)
        elseif event == "conack" then
            sys.publish("MQTT_CONNECT_" .. self.id)
            -- 恢复订阅
            for filter, cnt in pairs(self.subs) do
                if cnt > 0 then
                    -- log.info(tag, "recovery subscribe", filter)
                    client:subscribe(filter)
                end
            end
        elseif event == "disconnect" then
            sys.publish("MQTT_DISCONNECT_" .. self.id)
        end
    end)

    -- 处理MQTT消息，主要是回调中可能有sys.wait，所以必须用task
    sys.taskInit(function()
        while self.client do
            local ret, topic, payload = sys.waitUntil("MQTT_MESSAGE_" .. self.id, 30000)
            if ret then
                local ts = string.split(topic, "/")
                find_callback(self.sub_tree, ts, topic, payload)
            end
        end
        log.info(tag, "message handling task exit")
    end)

    -- 连接
    return self.client:connect()
end

--- 关闭平台（不太需要）
function MQTT:close()
    self.client:close()
    self.client = nil
end

--- 发布消息
-- @param topic string 主题
-- @param payload string|table|nil 数据，支持string,table
-- @param qos integer|nil 质量
-- @return integer 消息id
function MQTT:publish(topic, payload, qos)
    -- 转为json格式
    if type(payload) ~= "string" then
        local err
        payload, err = json.encode(payload, "2f")
        if payload == nil then
            payload = "payload json encode error:" .. err
        end
    end
    return self.client:publish(topic, payload, qos)
end

--- 订阅（检查重复订阅，只添加回调）
-- @param filter string 主题
-- @param cb function 回调
function MQTT:subscribe(filter, cb)
    log.info(tag, "subscribe", filter)

    -- 计数，避免重复订阅
    if not self.subs[filter] or self.subs[filter] <= 0 then
        self.client:subscribe(filter)
        self.subs[filter] = 1
    else
        self.subs[filter] = self.subs[filter] + 1
    end

    local fs = string.split(filter, "/")

    -- 创建树枝
    local sub = self.sub_tree
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
-- @param filter string 主题
-- @param cb function|nil 回调
function MQTT:unsubscribe(filter, cb)
    log.info(tag, "subscribe", filter)

    -- 取消订阅
    if self.subs[filter] ~= nil then
        if cb == nil then
            self.client:unsubscribe(filter)
        else
            self.subs[filter] = self.subs[filter] - 1
            if self.subs[filter] <= 0 then
                self.client:unsubscribe(filter)
            end
        end
    end

    local fs = string.split(filter, "/")

    -- 查树枝
    local sub = self.sub_tree
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
-- @return boolean 状态
function MQTT:ready()
    return self.client:ready()
end

return MQTT
