--- CJT188协议实现
--- @module "cjt188"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.09.11
local tag = "cjt188"

--- 设备类
--- @class Device
local Device = {}

---创建设备
---@param master Master 主站实例
---@param dev table 设备参数
---@return Device 实例
function Device:new(master, dev)
    local obj = dev or {}
    setmetatable(obj, self)
    self.__index = self
    obj.master = master
    return obj
end

function Device:open()

end

---读取数据
---@param key string 点位
---@return boolean 成功与否
---@return any
function Device:get(key)

end

---写入数据
---@param key string 点位
---@param value any 值
---@return boolean 成功与否
function Device:set(key, value)

end

---读取所有数据
---@return boolean 成功与否
---@return table|nil 值
function Device:poll()

end

local Master = {}

require("protocols").register("cjt188", Master)

---创建实例
---@param link any 连接实例
---@param opts table 协议参数
---@return Master
function Master:new(link, options)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.link = link
    obj.timeout = opts.timeout or 1000 -- 1秒钟
    obj.poller_interval = opts.poller_interval or 5 -- 5秒钟
    obj.increment = 1

    return obj
end

-- 读取数据
---@param slave integer 从站号
---@param code integer 功能码
---@param addr integer 地址
---@param len integer 长度
---@return boolean 成功与否
---@return string 只有数据
function Master:read(slave, code, addr, len)

end

-- 写入数据
---@param slave integer 从站号
---@param code integer 功能码
---@param addr integer 地址
---@param data string 数据
---@return boolean 成功与否
function Master:write(slave, code, addr, data)

end


---打开主站
function Master:open()

end

--- 关闭
function Master:close()
    self.opened = false
    self.devices = {}
end


--- 轮询
function Master:_polling()
    -- 轮询间隔
    local interval = self.poller_interval or 60
    interval = interval * 1000 -- 毫秒

    while self.opened do
        log.info(tag, "polling start")
        local start = mcu.ticks()

        -- 轮询连接下面的所有设备
        for _, dev in pairs(self.devices) do

            -- 加入异常处理（pcall不能调用对象实例，只是用闭包了）
            local ret, info = pcall(function()

                local ret, values = dev:poll()
                if ret then
                    log.info(tag, "polling", dev.id, "succeed")
                    -- log.info(tag, "polling", dev.id, "values", json.encode(values))
                    -- 向平台发布消息
                    -- cloud.publish("device/" .. dev.product_id .. "/" .. dev.id .. "/property", values)
                    sys.publish("DEVICE_VALUES", dev, values)
                else
                    log.error(tag, "polling", dev.id, "failed")
                end

            end)
            if not ret then
                log.error(tag, "polling", dev.id, "error", info)
            end

        end

        local finish = mcu.ticks()
        local remain = interval - (finish - start)
        if remain > 0 then
            sys.wait(remain)
        end
    end
end


