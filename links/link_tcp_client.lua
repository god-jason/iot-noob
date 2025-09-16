--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- TCP客户端，类定义
-- @module link_tcp_client
local Client = {}



local tag = "tcp client"

local increment = 1; -- 自增ID

require("links").register("tcp-client", Client)

function Client:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = opts.id or "tcp-" .. opts.host .. ":" .. opts.port
    obj.host = opts.host
    obj.port = opts.port
    obj.adapter = opts.adapter or socket.ETH0 -- 默认以太网卡
    obj.index = increment
    obj.asking = false

    increment = increment + 1 -- 自增ID
    return obj
end

-- 打开
function Client:open()
    -- 使用可用网络
    if self.adapter == nil then
        local ok, adapter = socket.adapter()
        if ok then
            self.adapter = adapter
        end
    end

    -- 创建socket
    self.ctrl = socket.create(self.adapter, function(ctrl, event, param)
        if param ~= 0 then
            -- sys.publish("socket_disconnect")
            return
        end

        if event == socket.LINK then
            log.info(tag, "LINK")
        elseif event == socket.ON_LINE then
            log.info(tag, "ON LINE")
            -- 连接成功
            -- self.ready = true
            sys.publish("TCP_CLIENT_READY_" .. self.index)
        elseif event == socket.EVENT then
            log.info(tag, "EVENT")

            sys.publish("TCP_CLIENT_DATA_" .. self.index)
            -- socket.rx(ctrl, rxbuf)
            -- socket.wait(ctrl)
        elseif event == socket.TX_OK then
            log.info(tag, "TX_OK")
            socket.wait(ctrl) -- 等待新状态
        elseif event == socket.CLOSED then
            log.info(tag, "CLOSED")
            sys.publish("TCP_CLIENT_CLOSE_" .. self.index)
        end
    end)

    -- socket.debug(self.ctrl, true)
    socket.config(self.ctrl, nil, nil, nil, 300, 5, 6) -- 开启TCP保活，防止长时间无数据交互被运营商断线

    -- 连接
    local ok, ret = socket.connect(self.ctrl, self.host, self.port)
    if not ok then
        socket.close()
        return false
    end
    if ret then
        return true
    end -- 连接成功

    -- 等待连接成功
    local res = sys.waitUntil(5000, "TCP_CLIENT_READY_" .. self.index)
    if not res then
        return false
    end

    return true
end

-- 写数据
function Client:write(data)
    -- return uart.write(self._id, data)
    socket.tx(self.ctrl, data)
end

-- 等待数据
function Client:wait(timeout)
    return sys.waitUntil("TCP_CLIENT_DATA_" .. self.index, timeout)
end

-- 读数据
function Client:read()
    -- 检测缓冲区是否有数据
    local ok, len = socket.rx(self.ctrl)
    if not ok then
        return false
    end
    if len > 0 then
        local ok2, data = socket.read(self.ctrl, len)
        socket.wait(self.ctrl) -- 等待新状态
        return ok2, data
    end
    return false
end

-- 关闭串口
function Client:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    socket.close(self.ctrl)
end

function Client:ready()
    local state = socket.state(self.ctrl)
    return state == 5 -- 在线状态
end


-- 询问
-- @param request string 发送数据
-- @param len integer 期望长度
-- @return boolean 成功与否
-- @return string 返回数据
function Client:ask(request, len)

    -- 重入锁，等待其他操作完成
    while self.asking do
        sys.wait(100)
    end
    self.asking = true

    -- log.info(tag, "ask", request, len)
    if request ~= nil and #request > 0 then
        local ret = self:write(request)
        if not ret then
            log.error(tag, "write failed")
            self.asking = false
            return false
        end
    end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    repeat
        -- TODO 应该不是每次都要等待
        local ret = self:wait(self.timeout)
        if not ret then
            log.error(tag, "read timeout")
            self.asking = false
            return false
        end

        local r, d = self:read()
        if not r then
            log.error(tag, "read failed")
            self.asking = false
            return false
        end
        buf = buf .. d
    until #buf >= len

    self.asking = false
    return true, buf
end

return Client
