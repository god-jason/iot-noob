--- 套接字管理
-- @module sockets
local sockets = {}

local log = iot.logger("socket")

-- 注册连接类型
local links = require("links")
local boot = require("boot")
local database = require("database")


local _sockets = {}

--- 套接字连接，继承Link
-- @module socket
local Socket = require("utils").class(require("event"))

--- 打开
-- @return boolean 成功与否
function Socket:open()
    log.info("open", self.host, self.port)
    local sock = iot.socket(self)

    -- 监听数据
    sock:on_data(function(data)
        log.info("socket data", self.host, self.port, data:toHex())
        if self.debug then
            iot.emit("link_debug", {
                id = self.id,
                type = "read",
                data = data
            })
        end
        self:emit("data", data)
    end)

    self.sock = sock
    
    return sock:open()
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Socket:write(data)
    log.info("write", self.host, self.port, data:toHex())
    local ret, info = self.sock:write(data)
    if ret and self.debug then
        iot.emit("link_debug", {
            id = self.id,
            type = "write",
            data = data
        })
    end
    return ret, info
end

--- 关闭套接字
function Socket:close()
    log.info("close", self.host, self.port)
    -- 关闭协议
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.sock:close()
    self:emit("close")
end


--- 加载
function sockets.open()
    local ss = database.find("socket")
    for i, t in ipairs(ss) do
        local ret, info = links.create(Socket, t)
        if not ret then
            log.error("连接套接字", t.host, t.port, " 出错:", info)
        else
            table.insert(_sockets, info)
        end
    end
    return true
end

--- 关闭
function sockets.close()
    for i, s in ipairs(_sockets) do
        s:close()
    end
    _sockets = {}
end

boot.register("sockets", sockets, "settings")

return sockets
