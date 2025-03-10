local tag     = "device"
local devices = {}

local configs = require("configs")

function devices.load_by_link(id)
    return configs.load("devices/"..id)
end

return devices
