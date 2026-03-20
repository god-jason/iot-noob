--- GPS模组
-- @module GPS
local GPS = {}
GPS.__index = GPS

require("components").register("gps", GPS)

local log = iot.logger("gps")

local function parse_latlng(raw, dir)
    if not raw or raw == "" then
        return nil
    end

    local dot = raw:find("%.")
    if not dot then
        return nil
    end

    local deg_len = dot - 3
    local deg = tonumber(raw:sub(1, deg_len))
    local min = tonumber(raw:sub(deg_len + 1))

    local val = deg + min / 60

    if dir == "S" or dir == "W" then
        val = -val
    end

    return val
end

local function parse_nmea(line)
    if not line or #line < 6 then
        return nil
    end

    local head = line:sub(2, 6) -- GPRMC / GNRMC

    local t = {}
    for v in string.gmatch(line, "([^,]+)") do
        table.insert(t, v)
    end

    -- ===== RMC =====
    if head:sub(3) == "RMC" then
        if t[3] ~= "A" then
            return nil
        end

        return {
            type = "RMC",
            time = t[2],
            lat = parse_latlng(t[4], t[5]),
            lng = parse_latlng(t[6], t[7]),
            speed = tonumber(t[8]) and tonumber(t[8]) * 1.852, -- km/h
            course = tonumber(t[9]),
            date = t[10]
        }
    end

    -- ===== GGA =====
    if head:sub(3) == "GGA" then
        return {
            type = "GGA",
            lat = parse_latlng(t[3], t[4]),
            lng = parse_latlng(t[5], t[6]),
            fix = tonumber(t[7]), -- 0无定位
            sats = tonumber(t[8]),
            hdop = tonumber(t[9]),
            alt = tonumber(t[10])
        }
    end

    return nil
end

--- 构造函数
function GPS:new(opts)
    opts = opts or {}
    local gps = setmetatable({
        port = opts.port or 2,
        baud_rate = opts.baud_rate or 9600,
        serial = nil,
        data = {},
        buffer = ""
    }, GPS)

    gps:init()

    return gps
end

function GPS:init()
    local ret, serial = iot.uart(self.port, {
        baud_rate = self.baud_rate,
        on_data = function(data)
            self:on_data(data)
        end
    })
    if not ret then
        log.error(serial)
        return
    end

    self:send("$PCAS03,1,0,0,0,0,0,0,0") -- 只开RMC
    -- self:send("$PCAS01,5") -- 115200

    self.serial = serial
end

function GPS:on_line(line)
    -- log.debug("gps raw", line)

    local d = parse_nmea(line)
    if not d then
        return
    end

    -- 合并数据
    for k, v in pairs(d) do
        self.data[k] = v
    end

    -- 事件
    iot.emit("GPS_UPDATE", self.data)
end

function GPS:on_data(data)
    self.buffer = self.buffer .. data

    while true do
        local s, e = self.buffer:find("\r\n")
        if not s then
            break
        end

        local line = self.buffer:sub(1, s - 1)
        self.buffer = self.buffer:sub(e + 1)

        self:on_line(line)
    end
end

function GPS:send(cmd)
    if self.serial then
        self.serial:write(self.uart_id, cmd .. "\r\n")
    end
end

function GPS:close()
    if self.serial then
        self.serial:close()
    end
end
