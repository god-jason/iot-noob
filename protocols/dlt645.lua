--- DL/T645 协议实现（07版）
-- @module dlt645
local dlt645 = {}

local log = iot.logger("dlt645")

local Request = require("request")
local binary = require("binary")
local utils = require("utils")
local devices = require("devices")
local protocols = require("protocols")
local model = require("model")
local meter = require("meter")

-- +0x33
local function add33(data)
    local t = {}
    for i = 1, #data do
        t[i] = string.char((data:byte(i) + 0x33) & 0xFF)
    end
    return table.concat(t)
end

-- -0x33
local function sub33(data)
    local t = {}
    for i = 1, #data do
        t[i] = string.char((data:byte(i) - 0x33) & 0xFF)
    end
    return table.concat(t)
end

-- Device
local DLT645Device = utils.class(require("device"))
dlt645.DLT645Device = DLT645Device

function DLT645Device:open()
    log.info("device open", self.id, self.product_id)
    self.model = model.get(self.product_id)
end

-- 读取单点
function DLT645Device:get(key)
    log.info("get", self.id, key)
    if not self.model then
        return false, "没有物模型" .. self.product_id
    end
    if not self.model.content then
        return false, "没有属性表" .. self.product_id
    end

    for _, pt in pairs(self.model.content) do
        for i, point in ipairs(pt.points) do
            if point.name == key then
                local ret, data = self.master:read(self.address, point.di)
                if not ret then
                    return false, data
                end

                -- 去掉DI（前4字节）
                data = data:sub(5)

                local ret, value = meter.decode(data, point.type, point.reverse)
                if not ret then
                    log.error("poll", self.id, point.name, "解析失败", value)
                    return false, value
                end

                -- 增加倍率转换（大部分不需要）
                if pt.rate and pt.rate ~= 0 and pt.rate ~= 1 then
                    value = value * pt.rate
                end

                return true, value
            end
        end
    end

    return false, "没有找到属性"
end

function DLT645Device:poll()
    log.info("poll", self.id)
    if not self.model then
        log.error("poll", self.id, "没有物模型")
        return false, "没有物模型"
    end
    if not self.model.content then
        log.error("poll", self.id, "没有属性表")
        return false, "没有属性表"
    end

    local has = false
    local values = {}
    for _, pt in pairs(self.model.content) do
        for i, point in ipairs(pt.points) do
            local ret, data = self.master:read(self.address, point.di)
            if not ret then
                log.error("poll", self.id, point.name, "读取失败", data)
            else
                -- 去掉DI（前4字节）
                data = data:sub(5)

                local ret, value = meter.decode(data, point.type, point.reverse)
                if not ret then
                    log.error("poll", self.id, point.name, "解析失败", value)
                else
                    -- 增加倍率转换（大部分不需要）
                    if pt.rate and pt.rate ~= 0 and pt.rate ~= 1 then
                        value = value * pt.rate
                    end

                    -- self:put_value(point.name, value)
                    -- 后面统一放入
                    values[point.name] = value
                    has = true
                end
            end
            iot.sleep(200)
        end
    end

    if has then
        self:put_values(values)
        return true
    end

    return false, "没有有效数据"
end

-- Master
local DLT645Master = utils.class()
dlt645.DLT645Master = DLT645Master

protocols.register("dlt645", DLT645Master)

function DLT645Master:init()
    self.link = self.link
    self.devices = self.devices or {}
    self.timeout = self.timeout or 1000
    self.request = Request:new(self.link, self.timeout)
    self.polling_interval = self.polling_interval or 60
    self.opened = false
end

-- 构建报文
function DLT645Master:build_frame(addr, ctrl, data)

    local frame = ""
    frame = frame .. string.char(0x68)

    -- 地址（低位在前）
    frame = frame .. binary.reverse(binary.decodeHex(addr))

    frame = frame .. string.char(0x68)
    frame = frame .. string.char(ctrl)

    local len = data and #data or 0
    frame = frame .. string.char(len)

    if data then
        frame = frame .. data
    end

    -- 校验
    local cs = crypto.checksum(frame, 1)
    frame = frame .. string.char(cs)

    frame = frame .. string.char(0x16)

    -- 前导码
    return binary.decodeHex("FEFEFEFE") .. frame
end

-- 请求
function DLT645Master:ask(addr, ctrl, di, payload)

    -- DI 低位在前
    local data = binary.reverse(binary.decodeHex(di))

    if payload then
        data = data .. payload
    end

    data = add33(data)

    local frame = self:build_frame(addr, ctrl, data)

    log.info("send", binary.encodeHex(frame))

    local ret, buf = self.request:request(frame, 12)
    if not ret then
        return false, buf or "no response"
    end

    log.info("recv", binary.encodeHex(buf))

    -- 去FE
    while #buf > 0 and buf:byte(1) == 0xFE do
        buf = buf:sub(2)
    end

    if buf:byte(1) ~= 0x68 then
        return false, "invalid start"
    end

    -- 长度
    local len = buf:byte(10)

    -- 补齐数据
    if #buf < len + 12 then
        local ret2, buf2 = self.request:request(nil, len + 12 - #buf)
        if not ret2 then
            return false, buf2
        end
        buf = buf .. buf2
    end

    -- 数据域
    local data = buf:sub(11, 11 + len - 1)

    data = sub33(data)

    return true, data
end

-- 读
function DLT645Master:read(addr, di)
    log.info("read", addr, di)
    --self.link:read()
    return self:ask(addr, 0x11, di, nil)
end

-- 写
function DLT645Master:write(addr, di, payload)
    log.info("write", addr, di)
    --self.link:read()
    return self:ask(addr, 0x14, di, payload)
end

-- 打开
function DLT645Master:open()
    if self.opened then
        return false
    end

    self.opened = true

    for _, d in ipairs(self.devices) do
        local dev = DLT645Device:new(d)
        dev.master = self
        dev:open()

        devices.register(d.id, dev)
    end

    -- 轮询
    if self.polling ~= false then
        iot.start(DLT645Master._polling, self)
    end

    return true
end

-- 关闭

function DLT645Master:close()
    self.opened = false
    self.devices = {}
end

-- 轮询

function DLT645Master:_polling()
    log.info("polling thread start")

    local interval = (self.polling_interval or 60) * 1000

    while self.opened do
        local start = mcu.ticks()

        for _, dev in pairs(self.devices) do
            iot.xcall(function()
                if dev.points then
                    for key, _ in pairs(dev.points) do
                        dev:get(key)
                        iot.sleep(200)
                    end
                end
            end)
        end

        local remain = interval - (mcu.ticks() - start)
        if remain > 0 then
            iot.sleep(remain)
        end
    end
end

return dlt645
