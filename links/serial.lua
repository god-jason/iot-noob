--- 串口连接，继承Link
-- @module serial
local Serial = {}
Serial.__index = Serial

local log = iot.logger("serial")

-- 继承Link
local Link = require("link")
setmetatable(Serial, Link)

-- 注册连接类型
local links = require("links")
links.register("serial", Serial)

---创建串口实例
-- @param opts table
-- @return table
function Serial:new(opts)
    local lnk = setmetatable(Link:new(), Serial)
    lnk.id = opts.id or "serial-" .. opts.port
    lnk.port = opts.port or 1
    lnk.options = opts
    return lnk
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    local ret, port = iot.uart(self.port, self.options)
    if not ret then
        return false, port
    end
    self.uart = port
    return true
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    log.info("write", self.port, data:toHex())
    if self.peer then
        return false, "透传时不能写"
    end
    return self.uart:write(data)
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Serial:wait(timeout)
    if self.peer then
        if timeout ~= nil and timeout > 0 then
            iot.sleep(timeout)
            return false, "透传中"
        end
        iot.sleep(1000)
        return false, "透传中"
    end

    return self.uart:wait(timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function Serial:read()
    if self.peer then
        return false, "透传时不能读"
    end

    local ret, data = self.uart:read()
    log.info("serial read", self.port, data:toHex())

    if ret then
        -- 转发到监听器
        -- self.watcher:dispatch(data)
        self:emit("data", data)
    end
    return ret, data
end

--- 开启透传
-- @param peer Link 对等连接
function Serial:pipe(peer)

    -- 正在透传的，直接替换，不再启动新进程
    if self.peer ~= nil then
        self.peer = peer
        return
    end

    self.peer = peer

    -- 传空是关闭
    if peer == nil then
        return
    end

    local this = self

    -- 读取当前数据并转发
    iot.start(function()
        while this.peer ~= nil do
            this.uart:wait(1000)
            local ret, data = this.uart:read()
            if ret and #data > 0 and this.peer ~= nil then
                log.info("serial write to peer", data:toHex())
                this.peer:write(data)
            end
        end
    end)

    -- 读取透传数据并转发
    iot.start(function()
        while this.peer ~= nil do
            this.peer:wait(1000)
            if this.peer ~= nil then
                local ret, data = this.peer:read()
                if ret and #data > 0 then
                    log.info("serial read from peer", data:toHex())
                    this.uart:write(data)
                end
            end
        end
    end)
end

--- 关闭串口
function Serial:close()
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.uart:close()
end

return Serial
