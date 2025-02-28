local tag = "CLIENT"


local id = 0;

--定义类
Client = {}

function Client:new(host, port)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.host = host
    obj.port = port
    obj.id = id
    id = id + 1 --自增ID
    return obj
end

-- 打开
function Client:open()
    self.ctrl = socket.create(nil, function(ctrl, event, param)
        if param ~= 0 then
            sys.publish("socket_disconnect")
            return
        end
        if event == socket.LINK then
        elseif event == socket.ON_LINE then
            -- 连接成功
            -- self.ready = true
            sys.publish("CLIENT_READY_"..self.id)
        elseif event == socket.EVENT then
            sys.publish("CLIENT_DATA_"..self.id)
            --socket.rx(ctrl, rxbuf)
            --socket.wait(ctrl)
        elseif event == socket.TX_OK then
            socket.wait(ctrl) --等待新状态
        elseif event == socket.CLOSED then
            sys.publish("CLIENT_CLOSE_"..self.id)
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
    if ret then
        -- 连接成功
        return true
    end

    -- 等待连接成功
    local res, data = sys.waitUtil(5000, "CLIENT_READY_"..self.id)
    if not res then
        return false
    end

    return true
end

-- 写数据
function Client:write(data)
    --return uart.write(self.id, data)
    socket.tx(self.ctrl, data)
end

-- 读数据，可能为空
function Client:read(len)
    local ok, data = socket.read(self.ctrl, len)
    socket.wait(self.ctrl) --等待新状态
    if ok then
        return data
    else
        return ""
    end
end

-- 关闭串口
function Client:close()
    socket.close(self.ctrl)
    log.info(tag, "close client", self.id)
end

function Client:ready()
    local state, str = socket.state(self.ctrl)
    return state == 5 --在线状态
end
