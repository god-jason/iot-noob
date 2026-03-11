local log = iot.logger("events")

local vm = require("vm")

-- 摄像头限位开关
iot.on("cam_limit1", function()
    vm.cam_stop()
end)
iot.on("cam_limit2", function()
    vm.cam_stop()
end)

-- 旋转限位开关
iot.on("turn_limit1", function()
    vm.turn_stop()
end)
iot.on("turn_limit2", function()
    vm.turn_stop()
end)

-- 机械臂 限位开关
iot.on("arm_limit1", function()
    vm.arm_stop()
end)
iot.on("arm_limit2", function()
    vm.arm_stop()
end)

-- 接水限位开关
iot.on("water_limit1", function()
    vm.water_stop()
end)
iot.on("water_limit2", function()
    vm.water_stop()
end)
