--- 模块功能：数据存储备份
-- @module storage
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.07.22
module(..., package.seeall)


local MOD = "STORAGE"

-- 启动存储服务
sys.taskInit(function()
    -- 挂载TF卡
    local ret = io.mount(io.SDCARD)
    if not ret then
        log.error(MOD, "挂载错误")
        return
    end

    while true do
        local ret, data = sys.waitUntil("POLLER")

        -- TODO 接收数据，打包存储
        -- 字段：设备ID，产品ID，时间戳，数据
        -- 存储格式：1 json，2 二进制，3 压缩的二进制 4 压缩的json

    end
end)

