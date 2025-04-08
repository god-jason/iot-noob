--- 百度云平台
--- @module "baidu"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.18
--- 源码参考： https://docs.openluat.com/air780epm/luatos/app/iotcloud/baiduiot/
local tag = "baidu"

local baidu = {}

local configs = require("configs")

local options = {
    product_id = "",
    device_name = "",
    device_secret = ""
}

local client = nil -- mqtt客户端



function baidu.init()
    log.info(tag, "init")

    local ret
    ret, options = configs.load(tag)
    if not ret then
        return false
    end

    options.region = options.region or "gz"
    options.host = options.product_id .. ".iot." .. options.region .. ".baidubce.com"
    options.ip = 1883
    if options.device_secret then
        options.client_id, options.user_name, options.password =
            iotauth.baidu(options.product_id, options.device_name, options.device_secret)
    elseif options.tls then
        options.ip = 1884
        options.isssl = true
        options.client_id = ""
        options.user_name = ""
        options.password = ""
    else
        return false
    end

    return true
end

function baidu.open()
    client = mqtt.create(nil, options.host, options.port, true)
    client:auth(options.client_id, options.user_name, options.password)
    --client:on(baidu_callback)
    client:connect()
end



return baidu
