--- 互补滤波器（增强版）
-- @module Complementary
local Complementary = {}
Complementary.__index = Complementary

require("filters").register("complementary", Complementary)

local log = iot.logger("comp")

function Complementary:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        alpha = opts.alpha or 0.98,

        -- 角度
        angle = opts.init or 0,

        -- 时间
        last_time = nil,
        auto_dt = opts.auto_dt ~= false,

        -- 陀螺仪零偏
        gyro_bias = opts.gyro_bias or 0,

        -- 限幅
        min = opts.min or -180,
        max = opts.max or 180
    }, Complementary)

    return obj
end

--- 更新时间差
function Complementary:_dt(dt)
    if not self.auto_dt then
        return dt or 0
    end

    local now = os.clock()
    if not self.last_time then
        self.last_time = now
        return 0
    end

    dt = now - self.last_time
    self.last_time = now
    return dt
end

--- 限幅
function Complementary:_clamp(v)
    if v > self.max then return self.max end
    if v < self.min then return self.min end
    return v
end

--- 更新
-- @param gyro 角速度（deg/s）
-- @param acc_angle 加速度角度（deg）
-- @param dt 可选
function Complementary:update(gyro, acc_angle, dt)
    dt = self:_dt(dt)
    if dt <= 0 then return self.angle end

    -- 去零偏
    gyro = gyro - self.gyro_bias

    -- 融合
    local angle_gyro = self.angle + gyro * dt
    self.angle = self.alpha * angle_gyro + (1 - self.alpha) * acc_angle

    -- 限幅
    self.angle = self:_clamp(self.angle)

    return self.angle
end

--- 设置角度（用于重置）
function Complementary:set(angle)
    self.angle = angle
end

--- 校准陀螺仪零偏（静止时调用）
function Complementary:calibrate(samples)
    samples = samples or 50
    local sum = 0

    for i = 1, samples do
        local g = self:_read_gyro() -- 需要你自己实现
        sum = sum + g
        sys.wait(10)
    end

    self.gyro_bias = sum / samples
    log.info("gyro bias:", self.gyro_bias)
end

return Complementary