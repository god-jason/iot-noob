--- LBS定位（使用合宙的LBS服务器）
-- @module LBS
local LBS = require("utils").class(require("component"))

require("components").register("lbs", LBS)

local log = iot.logger("LBS")

function LBS:init()
    self.latitude, self.longitude = 0, 0

    -- 开机定位
    -- iot.setTimeout(iot.start, 5000, LBS.locate, self)
    iot.setTimeout(iot.start, 5000, function()
        -- 网络没初始化，则等待
        if mobile.status() ~= 1 and mobile.status() ~= 5 then
            log.info("网络还没准备好")
            local ret = iot.wait("IP_READY", 15000)
            if not ret then
                return
            end
        end
        -- 调用定位
        self:locate()
    end)

    -- 周期定位
    if self.interval and self.interval > 0 then
        -- iot.setInterval(iot.start, self.interval * 60000, LBS.locate, self)
        iot.setInterval(iot.start, self.interval * 60000, function()
            self:locate()
        end)
    end
end

--- 高德LBS（需要先付5万，获得技术服务许可，坑爹玩意）
function LBS:amap()

    -- 当前基站
    local cell = mobile.scell()
    local bts = table.concat({cell.mcc, cell.mnc, cell.tac, cell.cid, cell.rssi}, ",")

    -- 附近基站
    local nearbts = {}

    mobile.reqCellInfo(15)
    sys.waitUntil("CELL_INFO_UPDATE", 15000)
    local cells = mobile.getCellInfo()
    for i, cell in ipairs(cells) do
        local bts = table.concat({cell.mcc, cell.mnc, cell.tac, cell.cid, cell.rssi}, ",")
        table.insert(nearbts, bts)
    end
    nearbts = table.concat(nearbts, "|")

    -- 接参数
    local params = {
        key = self.amap_key,
        accesstype = 0,
        cdma = 0,
        network = "GPRS",
        bts = bts, -- mcc,mnc,lac,cellid,signal
        nearbts = nearbts,
        imei = mobile.imei(),
        output = "JSON"
    }
    log.info("请求高德服务器", iot.json_encode(params))

    -- 发送地图请求
    local code, headers, body = iot.request("https://apilocate.amap.com/position", {
        query = params
    })
    if code ~= 200 then
        return false, "服务器返回错误" .. code
    end

    log.info("高德服务器返回内容", body)
    local data, err = iot.json_decode(body)
    if not data then
        return false, "数据返回错误：" .. err
    end

    if data.status == 0 then
        return false, "高德定位失败"
    end
    if data.info ~= "OK" then
        return false, "高德定位错误：" .. data.info
    end

    local ls = data.result.location:split(",")
    self.longitude, self.latitude = tonumber(ls[1]), tonumber(ls[2])

    iot.emit("location", {
        latitude = self.latitude,
        longitude = self.longitude,
        country = data.result.country,
        province = data.result.province,
        city = data.result.city,
        street = data.result.street,
        detail = data.result.desc, -- 详细地址
        radius = data.result.radius -- 精度 米
    })

    return true
end

--- 合宙AirLBS定位，高德接口10块每年，按模组收费，略贵
function LBS:airlbs()
    local ret, data = require("airlbs").request({
        project_id = self.project_id,
        project_key = self.project_key or PRODUCT_KEY
    })
    if not ret then
        return false, "airlbs定位失败"
    end
    self.latitude, self.longitude = data.lat, data.lng

    iot.emit("location", {
        latitude = self.latitude,
        longitude = self.longitude
    })

    return true
end

-- 合宙免费LBS定位，单基站，定位精度较差
function LBS:simple()
    local lat, lng, tm = require("lbsLoc2").request()
    if lat == nil then
        return false, "lbs定位失败"
    end
    self.latitude, self.longitude = tonumber(lat), tonumber(lng)

    iot.emit("location", {
        latitude = self.latitude,
        longitude = self.longitude
    })
    return true
end

function LBS:locate()
    log.info("locate")
    if mobile.status() ~= 1 and mobile.status() ~= 5 then
        return false, "网络未准备好，状态码" .. mobile.status()
    end

    local located = false
    local info

    -- 优先使用高德智能硬件定位
    if self.amap_key then
        located, info = self:amap()
    end

    -- 如果配置了项目ID和KEY，使用付费的airlbs
    if not located and self.project_id then
        located, info = self:airlbs()
    end

    -- 最后使用免费的LBS
    if not located then
        located, info = self:simple()
    end

    if not located then
        log.error("定位失败", info)
        return false, info
    end

    -- 如果定位成功，但发布消息
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
