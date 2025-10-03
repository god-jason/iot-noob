--- 套接字封装
-- @module socket
local Socket = {}
Socket.__index = Socket

local tag = "socket"

local increment = 1; -- 自增ID

---创建TCP实例
-- @param opts table
-- @return table
function Socket:new(opts)
    local obj = {}
    setmetatable(obj, self)
    obj.options = opts
    -- obj.adapter = opts.adapter or socket.ETH0 -- 默认以太网卡
    obj.id = increment
    increment = increment + 1 -- 自增ID
    return obj
end

--- 打开
-- @return boolean 成功与否
function Socket:open()
    if not self.buff then
        self.buff = zbuff.create(2048)
    end
    self.buff:clear()

    -- 使用可用网络
    if self.options.adapter == nil then
        local ok, adapter = socket.adapter()
        if ok then
            self.options.adapter = adapter
        end
    end

    -- 创建socket
    self.ctrl = socket.create(self.adapter or socket.ETH0, function(ctrl, event, param)
        if param ~= 0 then
            -- iot.emit("socket_disconnect")
            return
        end

        if event == socket.LINK then
            log.info(tag, "LINK")
        elseif event == socket.ON_LINE then
            log.info(tag, "ON LINE")
            -- 连接成功
            -- self.ready = true
            iot.emit("SOCKET_READY_" .. self.id)
        elseif event == socket.EVENT then
            log.info(tag, "EVENT")

            iot.emit("SOCKET_DATA_" .. self.id)
            -- socket.rx(ctrl, rxbuf)
            -- socket.wait(ctrl)
        elseif event == socket.TX_OK then
            log.info(tag, "TX_OK")
            socket.wait(ctrl) -- 等待新状态
        elseif event == socket.CLOSED then
            log.info(tag, "CLOSED")
            iot.emit("SOCKET_CLOSE_" .. self.id)
        end
    end)

    -- socket.debug(self.ctrl, true)
    -- 开启TCP保活，防止长时间无数据交互被运营商断线
    socket.config(self.ctrl, self.options.local_port, self.options.is_udp, self.options.is_tls, 300, 5, 6,
        self.options.server_cert, self.options.client_cert, self.options.client_key, self.options.client_password)

    -- 连接服务器
    local ok, ret = socket.connect(self.ctrl, self.host, self.port)
    if not ok then
        socket.close()
        return false
    end
    if ret then
        return true -- 连接成功
    end

    -- 等待连接成功 ON_LINE消息
    local res = iot.wait("SOCKET_READY_" .. self.id, 5000)
    if not res then
        return false
    end

    return true
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Socket:write(data)
    -- return uart.write(self._id, data)
    local ok, full, ret = socket.tx(self.ctrl, data)
    return ok
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Socket:wait(timeout)
    return iot.wait("SOCKET_DATA_" .. self.id, timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function Socket:read()
    -- 检测缓冲区是否有数据
    local ok, len = socket.rx(self.ctrl, self.buff)
    if not ok then
        return false
    end
    local data = self.buff:toStr()
    self.buff:clear()
    return true, data
end

--- 关闭
function Socket:close()
    socket.close(self.ctrl)
    self.buff:free()
    self.buff = nil
end

function Socket:ready()
    local state = socket.state(self.ctrl)
    return state == 5 -- 在线状态
end

return Socket
