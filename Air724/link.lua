--- 模块功能：链接管理
-- @module link
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30
module(..., package.seeall)

local MOD = "LINK"

--[[
Link {
    open(): bool
    close(): void
    write(data): bool
    read(timeout): string
}
]]

-- 构造器
local factories = {
    serial = require("links.serial").Serial.new,
    tcpclient = require("links.tcpclient").TcpClient.new
}

local links = {}

function poll()
    for _, dev in ipairs(devices) do
        local values = {}
        local prd = product.load(dev.product_id)
        for _, mapper in ipairs(prd.mappers) do
            local data = adapter.poll(dev, mapper)
            if data ~= false then
                for i, v in ipairs(data) do values[i] = v end
            else
                log.error(MOD, "轮询失败", prd.id, dev.id, mapper.code, mapper.addr, mapper.size)
            end
        end
        if #values > 0 then
            sys.publish("POLLER", prd.id, dev.id, values)
        else
            -- TODO 处理掉线逻辑
        end
    end
end
