--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- CAN总线类相关
-- @module can通道
local Can = {}

local tag = "Can"

require("links").register("can", Can)

---创建CAN总线实例
-- @param opts table
-- @return table
function Can:new(opts)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.id = opts.id or "can-" .. opts.port
    obj.port = opts.port or 0
    obj.listen = opts.listen or false -- 监听模式
    obj.node = opts.node -- 节点ID
    obj.acr = opts.acr or 0 -- 接收代码寄存器
    obj.amr = opts.amr or 0xffffffff -- 接收屏蔽寄存器
    obj.type = opts.ext and can.EXT or can.STD -- 扩展帧
    obj.baud_rate = opts.baud_rate or 100000 -- 默认100Kbps，上限1Mbps
    obj.pts = opts.pts or 5 -- 传输时间段 1-8
    obj.pbs1 = opts.pbs1 or 4 -- 相位缓冲段1 1-8
    obj.pbs2 = opts.pbs2 or 3 -- 相位缓冲段2 2-8
    obj.sjw = opts.sjw or 2 -- 同步补偿宽度值 1-4
    return obj
end

--- 打开
-- @return boolean 成功与否
function Can:open()
    local ret = can.init(self.port)
    if not ret then
        return ret, "init false"
    end

    -- 监听消息
    can.on(self.port, function(id, type, param)
        if type == can.CB_MSG then
            -- 收到消息
            sys.publish("CAN_DATA_" .. id)
        elseif type == can.CB_TX then
            -- 发送成功
            log.info(tag, self.port, "sent", param)
        elseif type == can.CB_ERR then
            -- 错误码
            log.info(tag, self.port, "error", mcu.x32(param))
        elseif type == can.CB_STATE then
            -- 发送成功
            log.info(tag, self.port, "state", param)
        end

    end)

    -- 配置时序
    ret = can.timing(self.port, self.pts, self.pbs1, self.pbs2, self.sjw)
    if not ret then
        return false, "timing false"
    end

    if self.listen then
        -- 监听模式
        can.filter(self.id, false, self.acr, self.amr)
        can.mode(self.id, can.MODE_LISTEN)

    else
        -- 节点模式，只能收到发给自己的数据
        can.node(self.id, self.node, self.type)
        can.mode(self.id, can.MODE_NORMAL)
    end

    return true
end

--- 写数据
-- @param data table 数据
-- @return boolean 成功与否
function Can:write(data)
    local id = data.id -- 节点ID
    local type = data.ext and can.EXT or can.STD
    local rtr = data.rtr or false
    local ack = data.ack or false
    return can.tx(self.port, id, type, rtr, ack, data)
end

-- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
function Can:wait(timeout)
    return sys.waitUntil("CAN_DATA_" .. self.port, timeout)
end

-- 读数据
-- @return boolean 成功与否
-- @return table|nil 数据
function Can:read()
    local ret, id, type, rtr, data = can.rx(self.port)
    if not ret then
        return false
    end
    local ext = type == can.EXT -- 扩展帧
    return true, {
        id = id,
        ext = ext,
        rtr = rtr,
        data = data
    }
end

-- 关闭CAN总线
function Can:close()
    can.deinit(self.port)
end

return Can
