--- TCP客户端，类定义
-- @module "Client"
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.03.01

local tag = "tcp client"

local id = 0;

--定义类
local Client = {}

require("links").register("tcp_client", Client)

function Client:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.host = opts.host
    obj.port = opts.port
    obj.adapter = opts.adapter or socket.ETH0 --默认以太网卡
    obj.id = id
    id = id + 1                              --自增ID
    return obj
end

-- 打开
function Client:open()
    --使用可用网络
    if self.adapter == nil then
        local ok, adapter = socket.adapter()
        if ok then
            self.adapter = adapter
        end
    end

    -- 创建socket
    self.ctrl = socket.create(self.adapter, function(ctrl, event, param)
        if param ~= 0 then
            --sys.publish("socket_disconnect")
            return
        end

        if event == socket.LINK then
        elseif event == socket.ON_LINE then
            -- 连接成功
            -- self.ready = true
            sys.publish("CLIENT_READY_" .. self.id)
        elseif event == socket.EVENT then
            sys.publish("CLIENT_DATA_" .. self.id)
            --socket.rx(ctrl, rxbuf)
            --socket.wait(ctrl)
        elseif event == socket.TX_OK then
            socket.wait(ctrl) --等待新状态
        elseif event == socket.CLOSED then
            sys.publish("CLIENT_CLOSE_" .. self.id)
        end
    end)

    --socket.debug(self.ctrl, true)
    socket.config(self.ctrl, nil, nil, nil, 300, 5, 6) --开启TCP保活，防止长时间无数据交互被运营商断线

    --连接
    local ok, ret = socket.connect(self.ctrl, self.host, self.port)
    if not ok then
        socket.close()
        return false
    end
    if ret then return true end -- 连接成功

    -- 等待连接成功
    local res, data = sys.waitUtil(5000, "CLIENT_READY_" .. self.id)
    if not res then return false end

    return true
end

-- 写数据
function Client:write(data)
    --return uart.write(self.id, data)
    socket.tx(self.ctrl, data)
end

-- 等待数据
function Client:wait(timeout)
    return sys.waitUtil("CLIENT_DATA_" + self.id, timeout)
end

-- 读数据
function Client:read()
    -- 检测缓冲区是否有数据
    local ok, len = socket.rx(self.ctrl)
    if not ok then return false end
    if len > 0 then
        local ok, data = socket.read(self.ctrl, len)
        socket.wait(self.ctrl) --等待新状态
        return ok, data
    end
    return false
end

-- 关闭串口
function Client:close()
    socket.close(self.ctrl)
end

function Client:ready()
    local state, str = socket.state(self.ctrl)
    return state == 5 --在线状态
end

return Client
