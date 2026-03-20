--- 网关主设备
-- @module master
local master = {}

local log = iot.logger("master")

local settings = require("settings")
local Device = require("device")
local boot = require("boot")

local device = Device:new({})
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

    -- 订阅添加子设备
    iot.on("DEVICE_REGISTER", function(id, device)
        -- 只绑定内联设备
        if device.inline then
            device:attach_children(device)    
        end
    end)

    -- 订阅删除子设备
    -- iot.on("DEVICE_UNREGISTER", function(id)
    --     device:detach_children(id)
    -- end)

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

master.deps = {"settings"}
boot.register("master", master)

settings.register("master", {
    interval = 1,
    devices = {},
    components = {}
})

return master
