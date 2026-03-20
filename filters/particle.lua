--- 粒子滤波器
-- @module Particle
local Particle = {}
Particle.__index = Particle

require("filters").register("particle", Particle)
local log = iot.logger("particle")

-- 创建粒子滤波器
-- opts:
--  num_particles: 粒子数量
--  init_state: 初始状态 {x, y, theta}
--  motion_noise: 运动噪声标准差 {x, y, theta}
--  sensor_noise: 传感器噪声标准差
function Particle:new(opts)
    local obj = setmetatable({}, self)
    obj.num_particles = opts.num_particles or 100
    obj.motion_noise = opts.motion_noise or {x=0.1, y=0.1, theta=0.05}
    obj.sensor_noise = opts.sensor_noise or 1.0

    -- 初始化粒子
    obj.particles = {}
    for i = 1, obj.num_particles do
        obj.particles[i] = {
            x = opts.init_state.x + math.random() * 0.01,
            y = opts.init_state.y + math.random() * 0.01,
            theta = opts.init_state.theta + math.random() * 0.01,
            weight = 1.0 / obj.num_particles
        }
    end
    return obj
end

-- 高斯随机数生成（安全处理 u1=0）
local function gaussian(mu, sigma)
    local u1 = math.random()
    local u2 = math.random()
    u1 = (u1 < 1e-10) and 1e-10 or u1
    local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
    return z0 * sigma + mu
end

-- 运动更新（预测）
-- control: {dx, dy, dtheta}
function Particle:predict(control)
    for _, p in ipairs(self.particles) do
        p.x = p.x + control.dx + gaussian(0, self.motion_noise.x)
        p.y = p.y + control.dy + gaussian(0, self.motion_noise.y)
        p.theta = p.theta + control.dtheta + gaussian(0, self.motion_noise.theta)
    end
end

-- 更新权重
-- measurement: 当前观测值
-- sensor_model: function(particle, measurement) -> likelihood
function Particle:update(measurement, sensor_model)
    local total_weight = 0
    for _, p in ipairs(self.particles) do
        p.weight = sensor_model(p, measurement)
        total_weight = total_weight + p.weight
    end
    -- 归一化权重
    if total_weight == 0 then
        -- 防止全零权重
        for _, p in ipairs(self.particles) do
            p.weight = 1.0 / self.num_particles
        end
    else
        for _, p in ipairs(self.particles) do
            p.weight = p.weight / total_weight
        end
    end
end

-- 低方差重采样
function Particle:resample()
    local new_particles = {}
    local N = #self.particles
    local r = math.random() / N
    local c = self.particles[1].weight
    local i = 1
    for m = 1, N do
        local U = r + (m-1)/N
        while U > c do
            i = i + 1
            c = c + self.particles[i].weight
        end
        local p = self.particles[i]
        new_particles[m] = {x=p.x, y=p.y, theta=p.theta, weight=1.0/N}
    end
    self.particles = new_particles
end

-- 估计当前状态（加权平均 + 角度修正）
function Particle:estimate()
    local x, y, sin_sum, cos_sum = 0, 0, 0, 0
    for _, p in ipairs(self.particles) do
        x = x + p.x * p.weight
        y = y + p.y * p.weight
        sin_sum = sin_sum + math.sin(p.theta) * p.weight
        cos_sum = cos_sum + math.cos(p.theta) * p.weight
    end
    local theta = math.atan2(sin_sum, cos_sum)
    return {x=x, y=y, theta=theta}
end

return Particle