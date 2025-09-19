--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025
--- CJT188协议实现
-- @module protocol_cjt188
local Device = {}

local tag = "cjt188"

local function encodeHex(str)
    local ret = ""
    for i = 1, #str do
        ret = ret .. string.format("%02X", str:byte(i))
    end
    return ret    
end

local function decodeHex(str)
    local ret = ""
    for i = 1, #str, 2 do
        local byteStr = str:sub(i, i+1)
        local byte = tonumber(byteStr, 16)
        ret = ret .. string.char(byte)
    end
    return ret
end

local function decodeBCD(len, str)
    local ret = 0
    for i = 1, len do
        local b = str:byte(i)
        local h = (b >> 4) & 0x0F
        local l = b & 0x0F
        ret = ret * 100 + h * 10 + l
    end
    return ret
end

local function encodeBCD(num, len)
    local str = ""
    for i = len, 1, -1 do
        local b = num % 100
        local h = (b // 10) & 0x0F
        local l = b % 10
        str = string.char((h << 4) | l) .. str
        num = num // 100
    end
    return str
end

local function decodeDatetime(str)
    local year = decodeBCD(1, str:sub(1, 1)) * 100 + decodeBCD(1, str:sub(2, 2))
    local month = decodeBCD(1, str:sub(3, 3))
    local day = decodeBCD(1, str:sub(4, 4))
    local hour = decodeBCD(1, str:sub(5, 5))
    local min = decodeBCD(1, str:sub(6, 6))
    local sec = decodeBCD(1, str:sub(7, 7))
    return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    })   
end

local function encodeDatetime(t)
    local tm = os.date("*t", t)
    local str = ""
    str = str .. encodeBCD(tm.year // 100, 1)
    str = str .. encodeBCD(tm.year % 100, 1)
    str = str .. encodeBCD(tm.month, 1)
    str = str .. encodeBCD(tm.day, 1)
    str = str .. encodeBCD(tm.hour, 1)
    str = str .. encodeBCD(tm.min, 1)
    str = str .. encodeBCD(tm.sec, 1)
    return str
end

local units = {
    [1] = "J",
    [2] = "Wh",
    [3] = "Whx10",
    [4] = "Whx100",
    [5] = "kWh",
    [6] = "kWhx10",
    [7] = "kWhx100",
    [8] = "MWh",
    [9] = "MWhx10",
    [0xA] = "MWhx100",
    [0xB] = "kJ",
    [0xC] = "kJx10",
    [0xD] = "kJx100",
    [0xE] = "MJ",
    [0xF] = "MJx10",
    [0x10] = "MJx100",
    [0x11] = "GJ",
    [0x12] = "GJx10",
    [0x13] = "GJx100",
    [0x29] = "L",
    [0x2A] = "Lx10",
    [0x2B] = "Lx100",
    [0x2C] = "m3",
    [0x2D] = "m3x10",
    [0x2E] = "m3x100"
}



---创建设备
-- @param master Master 主站实例
-- @param dev table 设备参数
-- @return Device 实例
function Device:new(master, dev)
    local obj = dev or {}
    setmetatable(obj, self)
    self.__index = self
    obj.master = master
    return obj
end

function Device:open()
    log.info(tag, "open")
    self.master.read(0, 0, 0, 0)
end

---读取数据
-- @param key string 点位
-- @return boolean 成功与否
-- @return any
function Device:get(key)
    log.info(tag, "get", key)
    self.master.read(0, 0, 0, 0)
end

---写入数据
-- @param key string 点位
-- @param value any 值
-- @return boolean 成功与否
function Device:set(key, value)
    log.info(tag, "set", key, value)
    self.master.read(0, 0, 0, 0)
end

---读取所有数据
-- @return boolean 成功与否
-- @return table|nil 值
function Device:poll()
    log.info(tag, "poll")
    self.master.read(0, 0, 0, 0)
end

local Master = {}

require("protocols").register("cjt188", Master)

---创建实例
-- @param link any 连接实例
-- @param opts table 协议参数
-- @return Master
function Master:new(link, opts)
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
-- @param slave integer 从站号
-- @param code integer 功能码
-- @param addr integer 地址
-- @param len integer 长度
-- @return boolean 成功与否
-- @return string 只有数据
function Master:read(slave, code, addr, len)
    log.info(tag, "read", slave, code, addr, len)
    self.link.ask("abc", 7)
end

-- 写入数据
-- @param slave integer 从站号
-- @param code integer 功能码
-- @param addr integer 地址
-- @param data string 数据
-- @return boolean 成功与否
function Master:write(slave, code, addr, data)
    log.info(tag, "write", slave, code, addr, data)
    self.link.ask("abc", 7)
end

---打开主站
function Master:open()
    log.info(tag, "open")
    local dev = Device:new()
    log.info(tag, dev)
    table.insert(self.devices, dev) -- 先随便写，不测试

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

