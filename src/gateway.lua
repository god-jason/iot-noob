--- 网关程序入口
-- @module gateway
-- @author 杰神
-- @license GPLv3
-- @copyright benyi
-- @release 2025.02.08
local tag = "gateway"
local gateway = {}

local configs = require("configs")
local cloud = require("cloud")
local links = require("links")
local ota = require("ota")

-- 处理OTA升级
local function on_ota(topic, payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- ota.download(data.url)
    sys.taskInit(ota.download, data.url)
end

-- 处理配置读取
local function on_config_read(topic, payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    local r, c = configs.load(data.name)
    if not r then
        return
    end
    cloud.publish("gateway/" .. cloud.id() .. "/config", {
        name = data.name,
        content = c
    })
end

-- 处理配置写入
local function on_config_write(topic, payload)
    local data, ret = json.decode(payload)
    if ret ~= 1 then
        -- 解析失败
        return
    end
    configs.save(data.name, data.content)
end


-- 开始透传
local function on_pipe_start(topic, payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- data.link TODO close protocol
    local link = links.get(data.link)
    cloud.subscribe("gateway/" .. cloud.id() .. "/" .. data.link .. "/down", function(topic, payload)
        link.write(payload)
    end)
    link.watch(function(data)
        cloud.publish("gateway/" .. cloud.id() .. "/" .. data.link .. "/up", data)
    end)
end


-- 结束透传
local function on_pipe_stop(topic, payload)
    local data, ret = json.decode(payload)
    if ret == 0 then
        return
    end
    -- data.link TODO open protocol
    local link = links.get(data.link)
    cloud.unsubscribe("gateway/" .. cloud.id() .. "/" .. data.link .. "/down")
    link.watch(nil)
end

-- 上报设备信息
local function report_info()
    local info = {
        bsp = rtos.bsp(),
        version = rtos.version(),
        firmware = rtos.firmware(),
        build = rtos.buildDate(),
        imei = mobile.imei(),
        imsi = mobile.imsi(),
        iccid = mobile.iccid()
    }
    cloud.publish("gateway/" .. cloud.id() .. "/info", info)
end

-- 上报设备状态（周期执行）
local function report_status()

    local total, used, top = rtos.meminfo()
    local ret, block_total, block_used, block_size = fs.fsstat()

    local status = {
        net = mobile.scell(),
        mem = {
            total = total,
            used = used,
            top = top
        },
        fs = {
            total = block_total * block_size,
            used = block_used * block_size,
            block = block_size,
        }
    }
    cloud.publish("gateway/" .. cloud.id() .. "/status", status)
end

--- 打开网关
function gateway.open()
    -- 打开连接
    links.load()

    -- 连接云平台
    cloud.open()

    sys.timerStart(report_info, 30000) -- 30秒上传信息
    sys.timerLoopStart(report_status, 60000) -- 60秒上传一次状态

    -- 订阅网关消息
    cloud.subscribe("gateway/" .. cloud.id() .. "/ota", on_ota)
    cloud.subscribe("gateway/" .. cloud.id() .. "/config/read", on_config_read)
    cloud.subscribe("gateway/" .. cloud.id() .. "/config/write", on_config_write)
    cloud.subscribe("gateway/" .. cloud.id() .. "/pipe/start", on_pipe_start)
    cloud.subscribe("gateway/" .. cloud.id() .. "/pipe/stop", on_pipe_stop)

end

--- 关闭网关
function gateway.close()
    
    
end

return gateway
