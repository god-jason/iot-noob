--- 模块功能：TCP客户端模式
-- @module client
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30
module(..., package.seeall)

-- 模块VMMC给模块供电
require 'pins'
require "socketCh395"
require "link"
require "socket"

-- ID
local _id = 0

local cfg = {
    mode = 1, -- 1表示客户端；2表示服务器；默认为1
    intPin = pio.P0_22, -- 以太网芯片中断通知引脚
    rstPin = pio.P0_21, -- 复位以太网芯片引脚
    powerFunc = function(state)
        if state then
            local setGpioFnc_TX = pins.setup(pio.P0_7, 0)
            pmd.ldoset(15, pmd.LDO_VMMC)
        else
            pmd.ldoset(0, pmd.LDO_VMMC)
            local setGpioFnc_TX = pins.setup(pio.P0_7, 1)
        end
    end,

    -- SPI通道参数，id,cpha,cpol,dataBits,clock
    spi = {spi.SPI_1, 0, 0, 8, 800000}
}

-- 启动socket客户端任务
sys.taskInit(function()
    -- 打开链路层网络类型
    sys.wait(5000)
    link.openNetwork(link.CH395, cfg)
    --TODO 此处会把4G网络替代掉
end)

-- 串口类
Client = {}

function Client:new(args)
    _id = _id + 1
    local obj = args or {id = _id, type = "tcp"}
    self.__index = self
    setmetatable(obj, Client)
    obj.ip = obj.ip or "192.168.1.12"
    obj.port = obj.port or 110
    return obj
end

function Client:open()
    if self.type == "udp" then
        self.client = socket.udp()
    elseif self.type == "tcp" then
        self.client = socket.tcp()
    else
        log.info(MOD, "unsupport", self.type)
    end

    if socket.isReady() and self.client:connect(self.ip, self.port) then
        --self.opened = true
        -- 连接成功
        return
    end

    -- 重连
    sys.timerStart(function() Client:open() end, 5000)
end

function Client:close() self.opened = false end

function Client:read(timeout)
    return self.client:recv(timeout)
    -- return sys.waitUntil("CLIENT_DATA_" .. self.id, timeout)
end

function Client:write(data) return self.client:send(data) end

