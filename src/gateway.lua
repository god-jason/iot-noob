--- 网关程序入口
-- @module gateway
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.02.08
local tag = "gateway"
local gateway = {}

local cloud = require("cloud")
local links = require("links")

function gateway.open()
    
    -- 连接云平台
    cloud.open()

    -- 打开连接
    links.open()
end

return gateway
