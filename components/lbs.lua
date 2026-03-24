--- LBS定位（使用合宙的LBS服务器）
-- @module LBS
local LBS = require("utils").class(require("component"))

require("components").register("lbs", LBS)

local log = iot.logger("LBS")

function LBS:init()
    self.latitude, self.longitude = 0, 0

    -- 开机定位    
    iot.setTimeout(iot.start, 5000, LBS.locate, self)

    -- 周期定位
    if self.interval and self.interval > 0 then
        iot.setInterval(iot.start, self.interval * 60000, LBS.locate, self)
    end
end

function LBS:locate()
    local located = false

    -- 如果配置了项目ID和KEY，优先使用付费的airlbs
    if self.project_id then
        local ret, data = require("airlbs").request({
            project_id = self.project_id,
            project_key = self.project_key or PRODUCT_KEY
        })
        if ret then
            self.latitude, self.longitude = data.lat, data.lng

            located = true
        else
            log.info("airlbs定位失败")
        end
    end

    -- 其实使用免费的LBS
    if not located then
        local lat, lng, tm = require("lbsLoc2").request()
        if lat ~= nil then
            self.latitude, self.longitude = tonumber(lat), tonumber(lng)
            located = true
        else
            log.info("lbs定位失败")
        end
    end

    -- 如果定位成功，但发布消息
    if located then
        self:emit("change", {
            latitude = self.latitude,
            longitude = self.longitude
        })

        iot.emit("location", {
            latitude = self.latitude,
            longitude = self.longitude
        })
    end

    return true, self.latitude, self.longitude
end

--- 设置
function LBS:set(key, value)
    log.info(self.pin, "set", key, value)
    if key == "locate" then
        return self:locate()
    else
        return false, "LBS组件不支持变量：" .. key
    end
    return true
end

function LBS:get(key)
    if key == "latitude" then
        return true, self.latitude
    elseif key == "longitude" then
        return true, self.longitude
    elseif key == "location" then
        self:locate() -- 主动定一次位
        return true, {self.latitude, self.longitude} -- 数组形式
    else
        return false, "LBS组件不支持变量：" .. key
    end
end
