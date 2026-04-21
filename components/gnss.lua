--- GNSS模组（依赖合宙的GPS模组）
-- @module GNSS
local GNSS = require("utils").class(require("component"))

require("components").register("gnss", GNSS)

local log = iot.logger("GNSS")

function GNSS:init()
    self.valid = false

    if self.auto then
        self:open()
    end
end

function GNSS:open()
    local exgnss = require("exgnss")

    local opts = {
        gnssmode = 1, -- 1 GPS+BD 2 BD
        agps_enable = self.agps ~= false, -- 默认开启AGPS，定位更快
        debug = self.debug == true
    }
    exgnss.setup(opts)

    -- 定位成功回调
    local function cb(mode)
        local rmc = exgnss.rmc(2)
        log.info("rmc", iot.json_encode(rmc))
        self.valid = rmc.valid
        self.latitude = rmc.lat
        self.longitude = rmc.lng
        self.speed = rmc.speed
        self.course = rmc.course
    end

    -- 定位时长
    local alive = self.alive or 60

    if self.mode == "TIMER" then
        -- 60s自动关闭
        exgnss.open(exgnss.TIMER, {
            tag = "TIMER",
            val = alive,
            cb = cb
        })
    elseif self.mode == "TIMERORSUC" then
        -- 60s自动关闭，定位成功也关闭
        exgnss.open(exgnss.TIMERORSUC, {
            tag = "TIMERORSUC",
            val = alive,
            cb = cb
        })
    else
        -- 一直开启
        exgnss.open(exgnss.DEFAULT, {
            tag = "DEFAULT",
            cb = cb
        })
    end
end

function GNSS:close()
    local exgnss = require("exgnss")

    exgnss.close(exgnss.TIMER, {
        tag = "TIMER"
    })
    exgnss.close(exgnss.TIMERORSUC, {
        tag = "TIMERORSUC"
    })
    exgnss.close(exgnss.DEFAULT, {
        tag = "DEFAULT"
    })
end

--- 设置数据
function GNSS:set(key, value)
    log.info(self.pin, "set", key, value)
    if key == "locate" then
        self:open()
    else
        return false, "GNSS组件不支持变量：" .. key
    end
    return true
end

--- 获取数据
function GNSS:get(key)
    if key == "latitude" then
        return true, self.latitude
    elseif key == "longitude" then
        return true, self.longitude
    elseif key == "speed" then
        return true, self.speed
    elseif key == "course" then
        return true, self.course
    elseif key == "location" then
        return true, {self.latitude, self.longitude} -- 数组形式
    else
        return false, "GNSS组件不支持变量：" .. key
    end
end
