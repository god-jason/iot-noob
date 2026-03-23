--- 网关主设备
-- @module master
local master = {}

local log = iot.logger("master")

local settings = require("settings")
local Device = require("device")
local boot = require("boot")

local MasterDevice = require("utils").class(require("device"))

--- 创建设备实例
-- @param obj table 设备
-- @return Device 设备实例
function MasterDevice:init()
    -- log.info("MasterDevice:init")
end

---  写值（重写Deivce:set，支持组件变量）
-- @param key string
-- @param value any
-- @return boolean, error
function MasterDevice:set(key, value)
    log.info("set", key, value)

    -- 查找内联设备
    for k, dev in pairs(self._children) do
        local val = dev._values[key]
        if val ~= nil then
            return dev:set(key, value)
        end
    end

    -- 组件绑定变量（组件多的话，效率有点低，不过set应用场景不多，后期可以加索引）
    for k, cmp in ipairs(settings.components) do
        if cmp.bindings then
            local com = components[cmp.name]
            if com and com.set then
                for k, v in pairs(cmp.bindings) do
                    if v == key then
                        return com:set(k, value)
                    end
                end
            end
        end
    end

    -- 基础处理
    self._values[key] = {
        value = value,
        time = os.time()
    }

    -- self.put_value(key, value)
    return true
end

local device = MasterDevice:new({})
master.device = device
-- devices.register("$master$", device)

--- 更新数据
function master.update_status()
    -- 计算内存占用
    local total, used, top = rtos.meminfo()

    device:put_values({
        memory = math.ceil(used / total * 100),
        csq = mobile.csq()
    })
end

--- 打开网关
function master.open()

    -- 注册到全局
    device.id = settings.master.id or mobile.imei()
    devices[device.id] = device

    -- 组件绑定 组件变量=>网关变量
    -- bindings = {
    --    state = forward_state,
    --    disabled = forward_disabled
    -- }
    for k, cmp in ipairs(settings.components) do
        local com = components[cmp.name]
        if cmp.bindings and com and com.on then
            com:on("change", function(values)
                local has = false
                local vs = {}
                for k, v in pairs(values) do
                    local key = cmp.bindings[k]
                    if key ~= nil then
                        vs[key] = v
                        has = true
                    end
                end
                if has then
                    device:put_values(vs)
                end
            end)
        end
    end

    -- 订阅添加子设备
    iot.on("DEVICE_REGISTER", function(device)
        -- 只绑定内联设备
        if device.inline then
            device:attach_children(device)
        end
    end)

    -- 订阅删除子设备
    iot.on("DEVICE_UNREGISTER", function(id)
        device:detach_children(id)
    end)

    -- 放入初始数据
    device:put_values({
        bsp = rtos.bsp(),
        project = PROJECT,
        version = VERSION,
        firmware = rtos.firmware(),
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid()
    })

    iot.setInterval(master.update_status, (settings.master.interval or 1) * 60 * 1000)
end

master.deps = {"settings", "components"}
boot.register("master", master)

settings.register("master", {
    interval = 1
})

return master
