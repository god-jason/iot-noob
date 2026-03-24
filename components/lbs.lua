--- LBS定位（使用合宙的LBS服务器）
-- @module LBS
local LBS = require("utils").class(require("component"))

require("components").register("lbs", LBS)

local log = iot.logger("LBS")

function LBS:init()
    self.latitude, self.longitude = 0, 0

    -- 定时定位    
    iot.setTimeout(iot.start, 5000, function()
        self:locate()
    end)
end

function LBS:locate()
    -- 如果配置了项目ID和KEY，就使用付费的airlbs
    if self.project_id then
        local ret, data = require("airlbs").request({
            project_id = self.project_id,
            project_key = self.project_key or PRODUCT_KEY
        })
        if ret then
            self.latitude, self.longitude = data.lat, data.lng
            self:emit("change", {
                latitude = self.latitude,
                longitude = self.longitude
            })
            return true, self.latitude, self.longitude
        end
    end

    -- 默认使用免费的
    local lat, lng, tm = require("lbsLoc2").request()
    if lat == nil then
        return false, "LBS服务器调用失败"
    end
    self.latitude, self.longitude = lat, lng
    self:emit("change", {
        latitude = self.latitude,
        longitude = self.longitude
    })

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
