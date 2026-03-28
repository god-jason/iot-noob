--- 串口管理
-- @module serials
local serials = {}

local log = iot.logger("serial")

-- 注册连接类型
local links = require("links")
local boot = require("boot")
local database = require("database")

local _serials = {}

--- 串口连接，继承Link
-- @module serial
local Serial = require("utils").class(require("event"))

---创建串口实例
-- @param opts table
-- @return table
function Serial:init()
    self.name = self.name or "串口" .. self.port
    self.type = "串口"
end

--- 打开
-- @return boolean 成功与否
function Serial:open()
    local ret, port = iot.uart(self.port, self)
    if not ret then
        return false, port
    end

    -- 监听数据
    port:on_data(function(data)
        log.info("serial data", self.port, data:toHex())
        self:emit("data", data)
    end)

    self.uart = port
    return true
end

--- 写数据
-- @param data string 数据
-- @return boolean 成功与否
function Serial:write(data)
    log.info("write", self.port, data:toHex())
    return self.uart:write(data)
end

--- 关闭串口
function Serial:close()
    -- 关闭协议
    if self.instanse ~= nil then
        self.instanse:close()
    end
    self.uart:close()
    self:emit("close")
end

--- 加载镜像
function serials.open()
    local ss = database.find("serial")
    for i, t in ipairs(ss) do
        local ret, info = links.create(Serial, t)
        if not ret then
            log.error("连接串口", t.port, t.name, " 出错:", info)
        else
            table.insert(_serials, info)
        end
    end
    return true
end

--- 关闭镜像
function serials.close()
    for i, s in ipairs(_serials) do
        s:close()
    end
    _serials = {}
end

boot.register("serials", serials, "settings")

return serials
