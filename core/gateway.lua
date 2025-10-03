--- 网关管理
-- @module gateway
local gateway = {}

local tag = "gateway"

local database = require("database")
local configs = require("configs")

local options = {}

local global = {
    iot = require("iot"), -- 所有IOT接口
    database = require("database"), -- 数据库
    kv = require("kv"), -- KV数据库
    devices = {}, -- 所有设备实例
    links = {}, -- 所有连接实例
    gpios = {}, -- 所有GPIO实例
    uarts = {}, -- 所有UART实例
    i2cs = {}, -- 所有I2C实例
    spis = {}, -- 所有SPI实例
    adcs = {}, -- 所有ADC实例
    pwms = {} -- 所有PWM实例
}

--- 注册设备实例
-- @param id string 设备ID
-- @param dev Device 子类实例
function gateway.register_device_instanse(id, dev)
    global.devices[id] = dev
end

--- 反注册设备实例
-- @param id string 设备ID
function gateway.unregister_device_instanse(id)
    table.remove(global.devices, id)
end

--- 获得设备实例
-- @param id string 设备ID
-- @return Device 子实例
function gateway.get_device_instanse(id)
    return global.devices[id]
end

--- 获得所有设备实例
-- @return table id->Device 实例
function gateway.get_all_device_instanse()
    return global.devices
end

local links = {}

--- 注册连接类
-- @param name string 类名
-- @param class Object 类定义
function gateway.register_link(name, class)
    links[name] = class
end

--- 注册连接实例
-- @param id string 连接ID
-- @param lnk Link 子类实例
function gateway.register_link_instanse(id, lnk)
    global.links[id] = lnk
end

--- 反注册连接实例
-- @param id string 连接ID
function gateway.unregister_link_instanse(id)
    table.remove(global.links, id)
end

--- 获得连接实例
-- @param id string 连接ID
-- @return Device 子实例
function gateway.get_link_instanse(id)
    return global.links[id]
end

--- 协议类型
local protocols = {}

--- 注册协议
-- @param name string 类名
-- @param class Object 类定义
function gateway.register_protocol(name, class)
    protocols[name] = class
end

--- 创建连接
-- @param type string 连接类型
-- @param opts table 参数
-- @return boolean 成功与否
-- @return Link|error 实例
function gateway.create_link(type, opts)
    local link = links[type]
    if not link then
        return false, "找不到连接类"
    end

    -- return true, link:new(opts)
    local lnk = link:new(opts or {})
    local ret, err = lnk:open()
    log.info(tag, "open link", link.id, ret, err)
    if not ret then
        return false, err
    end

    global.links[lnk.id] = lnk -- 注册实例

    -- 没有协议，直接返回，可能是透传
    if not lnk.protocol then
        return true, lnk
    end

    local protocol = protocols[lnk.protocol]
    if not protocol then
        return true, lnk
    end

    local instanse = protocol:new(lnk, lnk.protocol_options or {})
    ret, err = instanse:open()
    log.info(tag, "open protocol", ret, err)

    if ret then
        -- 协议实例保存下来
        lnk.instanse = instanse
    end

    return true, lnk
end

--- 关闭连接
-- @param id string 连接ID
function gateway.close_link(id)
    local lnk = global.links[id]
    if not lnk then
        lnk:close()
        table.remove(global.links, id)
    end
end

--- 加载所有连接
function gateway.load_links()
    log.info(tag, "load links")

    local lns = database.find("link")
    if #lns == 0 then
        return
    end

    for _, link in ipairs(lns) do
        log.info(tag, "load link", link.id, link.type)
        local ret, lnk = gateway.create_link(link.type, link)
        log.info(tag, "create link", link.id, link.type, ret, lnk)
    end
end

-- 加载GPIO
local function load_gpio()
    for i, obj in ipairs(options.gpio) do
        local ret, p = iot.gpio(obj.id, obj)
        log.info(tag, "open gpio", ret, p)
        if ret then
            global.gpios[obj.id] = p
        end
    end
end

-- 加载I2C
local function load_i2c()
    for i, obj in ipairs(options.i2c) do
        local ret, p = iot.i2c(obj.id, obj)
        log.info(tag, "open i2c", ret, p)
        if ret then
            global.i2cs[obj.id] = p
        end
    end
end

-- 加载SPI
local function load_spi()
    for i, obj in ipairs(options.spi) do
        local ret, p = iot.spi(obj.id, obj)
        log.info(tag, "open spi", ret, p)
        if ret then
            global.spis[obj.id] = p
        end
    end
end

-- 加载ADC
local function load_adc()
    for i, obj in ipairs(options.adc) do
        local ret, p = iot.adc(obj.id, obj)
        log.info(tag, "open adc", ret, p)
        if ret then
            global.adcs[obj.id] = p
        end
    end
end

-- 加载PWM
local function load_pwm()
    for i, obj in ipairs(options.pwm) do
        local ret, p = iot.pwm(obj.id, obj)
        log.info(tag, "open pwm", ret, p)
        if ret then
            global.pwms[obj.id] = p
        end
    end
end

-- 加载UART
local function load_uart()
    for i, obj in ipairs(options.uart) do
        local ret, p = iot.uart(obj.id, obj)
        log.info(tag, "open uart", ret, p)
        if ret then
            global.uarts[obj.id] = p
        end
    end
end

--- 执行脚本（用户自定义逻辑）
-- @param script 脚本
-- @return boolean 成功与否
-- @return any|error 结果
function gateway.execute(script)
    local fn = load(script, "gateway_script", "bt", global)
    if fn ~= nil then
        local ret, info = pcall(fn)
        return ret, info
    else
        return false, "编译错误"
    end
end

--- 启动网关主程序
function gateway.boot()

    -- 加载配置
    options = configs.load_default("gateway", {})

    -- 加载硬件接口
    load_uart()
    load_gpio()
    load_i2c()
    load_spi()
    load_adc()
    load_pwm()

    -- 加载所有连接
    gateway.load_links()

end

-- 创建设备
-- @param dev table 设备
-- @return boolean 成功与否
-- @return Link|error 实例
-- function gateway.create_device(dev)
--     local lnk = board.links[dev.link_id]
--     if lnk and lnk.instanse then
--         lnk.instanse.attach(dev)
--     else
--         board.devices[dev.id] = Device:new(dev)
--     end
-- end

-- 加载所有设备
-- function gateway.load_devices()
--     local dvs = database.find("device")
--     if #dvs == 0 then
--         return
--     end

--     for _, dev in ipairs(dvs) do
--         gateway.create_device(dev)
--     end

-- end

return gateway
