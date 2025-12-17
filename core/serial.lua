--- 串口连接，继承Link
-- @module serial
local Serial = {}
Serial.__index = Serial

local Link = require("link")
setmetatable(Serial, Link) -- 继承Link

-- require("gateway").register_link("serial", Serial)
local gateway = require("gateway")
gateway.register_link("serial", Serial)

---创建串口实例
-- @param opts table
-- @return table
function Serial:new(opts)
    local lnk = Link:new()
    setmetatable(lnk, self)
    lnk.id = opts.id or "serial-" .. opts.port
    lnk.port = opts.port or 1
    lnk.options = opts
    return lnk
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    self.uart = gateway.uarts[self.port]
    if not self.uart then
        return false, "找不到串口实例"
    end
    return true
    -- local ret, obj = iot.uart(self.port, self.options)
    -- if ret then
    --     self.uart = obj
    -- end
    -- return ret
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    if self.peer then
        return false, "cannot write when piping"
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
            return false, "no data while piping"
        end
        iot.sleep(1000)
        return false, "no data while piping"
    end

    return self.uart:wait(timeout)
end

--- 读数据
-- @return boolean 成功与否
-- @return string|nil 数据
function Serial:read()
    if self.peer then
        return false, "cannot read when piping"
    end

    local ret, data = self.uart:read()
    if ret and self.watcher then
        self.watcher(data) -- 转发到监听器
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
