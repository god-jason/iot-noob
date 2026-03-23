--- 设备绑定，同步，配对，镜像
-- @module bindings
local bindings = {}

local log = iot.logger("bindings")

local boot = require("boot")

local settings = require("settings")
local master = require("master")

local _bridges = {}

--- 设备镜像
-- @module Binding
local Binding = {}
Binding.__index = Binding

function Binding:new(dev1, dev2)
    local obj = setmetatable({
        dev1 = dev1,
        dev2 = dev2
    }, Binding)
    obj:init()
    return obj
end

function Binding:init()

    -- 订阅设备1的变化
    self.sub1 = self.dev1:on("change", function(values)
        -- 触发其他 change 监听
        self.dev2:put_values(values)

        -- 回写外设的寄存器
        iot.start(function()
            for k, v in pairs(values) do
                local ret, info = self.dev2:set(k, v)
                if not ret then
                    log.error(info)
                end
            end
        end)
    end)

    -- 订阅设备2的变化
    self.sub2 = self.dev2:on("change", function(values)
        -- 触发其他 change 监听
        self.dev1:put_values(values)

        -- 回写外设的寄存器
        iot.start(function()
            for k, v in pairs(values) do
                local ret, info = self.dev1:set(k, v)
                if not ret then
                    log.error(info)
                end
            end
        end)
    end)
end

--- 关闭
function Binding:close()
    if self.sub1 then
        self.sub1()
        self.sub1 = nil
    end
    if self.sub2 then
        self.sub2()
        self.sub2 = nil
    end
end

-- 查找设备
local function find_device(id)
    -- 未传值，则使用网关设备
    if not id or id == "" or master.device.id == id then
        return master.device
    end
    return devices[id]
end


--- 创建镜像
function bindings.create(mirror)
    log.info("create", iot.json_encode(mirror))

    local dev1 = find_device(mirror.device1)
    if not dev1 then
        return false, "找不到第一个设备"
    end

    local dev2 = find_device(mirror.device2)
    if not dev2 then
        return false, "找不到第二个设备"
    end

    local s = Binding:new(dev1, dev2)
    table.insert(_bridges, s)

    return true, s
end

--- 加载镜像
function bindings.open()
    local ss = settings.bindings or {}
    for i, s in ipairs(ss) do
        local ret, info = bindings.create(s)
        if not ret then
            log.error("mirror:", s.device1, s.device2, " open error:", info)
        end
    end
    return true
end

--- 关闭镜像
function bindings.close()
    for i, s in ipairs(_bridges) do
        s:close()
    end
    _bridges = {}
end

bindings.deps = {"links", "settings"}

settings.register("bindings", {})

boot.register("bindings", bindings)