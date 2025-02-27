--- 模块功能：物联小白云平台连接
-- @module noob
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30

module(..., package.seeall)
-- 连接云平台

require "misc"
require "mqtt"
require "config"

local MOD = "NOOB"
local CFG = "noob"

-- TODO 添加备份服务器
local imei = misc.getImei()
log.info(MOD, "imei", imei)

cfg = {
    clientId = imei, -- 默认使用IMEI号
    username = "", -- TODO 账号密码规则
    password = "",
    server = "mqtt.iot-noob.com",
    port = 1883
}


-- 加载配置
local ok, res = config.load(CFG)
if ok then
    cfg = res
else
    config.store(CFG, cfg) -- 生成默认文件
end



-- MQTT Broker 参数配置
local ready = false

function isReady() return ready end

-- 客户端
local client

-- 数据发送的消息队列
local _msgQueue = {}

-- 要订阅的主题
local topics = {["down/gateway/" .. imei .. "/#"] = 0}

--- 发布消息
function close() client:close() end

--- 发布消息
function publish(topic, payload, cb)
    log.info(MOD, "publish", topic, payload)
    table.insert(_msgQueue, {t = topic, p = payload, q = 0, c = cb})
    sys.publish("APP_SOCKET_SEND_DATA") -- 终止接收等待，处理发送
end

-- 订阅消息 TODO 添加callback
function subscribe(topic, qos)
    topics[topic] = qos
    if ready then return client:subscribe({[topic] = qos}) end
end

local function send_messages()
    while #_msgQueue > 0 do
        local msg = table.remove(_msgQueue, 1)
        local ok = client:publish(msg.t, msg.p, msg.q)
        if msg.c then msg.c(ok) end
        if not ok then return end
    end
    return true
end

local function receive_messages()
    local ok, data
    while true do
        -- 接收到数据
        ok, data = client:receive(60000, "APP_SOCKET_SEND_DATA")
        if ok then
            log.info(MOD, "message", data.topic, data.payload)

            local ts = string.split(data.topic, "/")
            if ts[1] == "down" then
                if ts[2] == "gateway" then
                    if ts[4] == "command" then
                        handleCommand(data.payload)
                    end
                elseif ts[2] == "property" then
                    -- TODO 数据怎么回传


                end
            end
        else
            break
        end
    end

    return ok or data == "timeout" or data == "APP_SOCKET_SEND_DATA"
end

-- 启动NOOB客户端任务
sys.taskInit(function()
    local retry = 0
    while true do
        if not socket.isReady() then
            retry = 0
            -- 等待网络环境准备就绪，超时时间是5分钟
            sys.waitUntil("IP_READY_IND", 300000)
        end

        if socket.isReady() then

            client = mqtt.client(cfg.clientId, 600, cfg.username, cfg.password)
            -- 阻塞执行MQTT CONNECT动作，直至成功
            if client:connect(cfg.server, cfg.port, "tcp") then
                retry = 0
                ready = true

                -- 订阅主题
                client:subscribe(topics)

                -- 循环处理接收和发送的数据
                while true do
                    if not receive_messages(client) then
                        log.error(MOD, "receive error")
                        break
                    end
                    if not send_messages(client) then
                        log.error(MOD, "send error")
                        break
                    end
                end

                ready = false
            else
                retry = retry + 1
            end

            -- 断开MQTT连接
            client:disconnect()
            if retry >= 5 then
                link.shut()
                retry = 0
            end
            sys.wait(5000)
        else
            -- 飞行模式20秒，重置网络
            net.switchFly(true)
            sys.wait(20000)
            net.switchFly(false)
        end
    end
end)


require "..command"
-- 处理命令
local function handleCommand(payload)
    log.info(MOD, "handleCommand", payload)
    local msg = json.decode(payload)

    local ret

    local fn = command[msg.cmd]
    if fn == nil then
        log.info("noob", "unkown command", msg.cmd)
        ret = command.reply(msg, {ret = 0, error = "unkown command"})
    else
        ret = fn(msg)
    end

    local topic = "up/gateway" .. imei .. "/command"
    local payload = json.encode(ret)
    -- Publish(topic, payload)
    table.insert(_msgQueue, {t = topic, p = payload, q = 0})
end
