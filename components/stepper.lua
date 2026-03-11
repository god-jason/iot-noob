local log = iot.logger("stepper")

local Stepper = {}
Stepper.__index = Stepper

require("components").register("stepper", Stepper)

--- 创建步进电机
---@param id integer PWM号
---@param dir integer 方向引脚
---@param reverse boolean 电机反转（适用于接线装反的场景）
---@param en integer 使能引脚
---@param freq integer  基础频率(一周的脉冲数)
---@param smooth boolean 平滑过渡
function Stepper:new(opts)
    opts = opts or {}
    local stepper = setmetatable({
        pwm_id = opts.idpwm_id,
        dir = opts.dir,
        en = opts.en,
        reverse = opts.reverse or false,
        freq = opts.freq or 16000,
        smooth = opts.smooth or false
    }, Stepper)
    stepper:init()
    return stepper
end

-- 初始化
function Stepper:init()
    self.running = false
    self.dir_pin = iot.gpio(self.dir)
    self.en_pin = iot.gpio(self.en)

    -- 默认使用低电平有效的驱动器
    self.en_pin:set(1)
end

--- 运行（转速，圈数）
---@param rpm number 转速
---@param rounds number 圈数
---@return integer 需要等待时间ms
function Stepper:start(rpm, rounds)
    log.info(self.pwm, "start rpm", rpm, "rounds", rounds)
    -- if self.running then
    --     -- 电机驱动必须先把PWM停下，再修改频率才有效
    --     --pwm.stop(self.pwm)
    -- end
    self.running = true

    -- 方向
    if rounds >= 0 then
        self.dir_pin:set(self.reverse and 0 or 1)
    else
        self.dir_pin:set(self.reverse and 1 or 0)
    end

    -- 取正
    rounds = math.abs(rounds)

    -- 使能
    self.en_pin:set(0)

    local freq = math.floor(self.freq * rpm / 60)
    local count = math.floor(self.freq * rounds)

    log.info(self.pwm, "start freq", freq, "count", count)

    -- 加减速
    if self.smooth then
        local tm, pulse = self:accelerate(self.last or 0, freq, count)
        count = count - pulse -- 要减去加速的脉冲数

        -- 目标速度是0，需要停止
        if freq == 0 then
            self:stop()
            return 0
        end

        -- sleep产生变化
        if not self.running then
            self:stop()
            return 0
        end
    end

    -- 记录上次速度
    self.last = freq

    -- 停止
    if count <= 0 then
        self:stop()
    end

    log.info(self.pwm_id, "start", freq, "count", count)
    local time = math.floor(count / freq * 1000)

    -- 先停止再改速
    -- pwm.stop(self.pwm)
    if self.pwm then
        self.pwm:stop()
    end

    -- 匀速运行
    if freq > 0 and count > 0 then
        -- pwm.setup(self.pwm, freq, 50, count)
        -- pwm.start(self.pwm)
        local ret, pwm = iot.pwm(self.pwm_id, {
            freq = self.freq,
            duty = 50,
            count = count
        })
        if ret then
            self.pwm = pwm
            pwm:start()
        end
    end
    return time
end

-- 刹车（至零）
function Stepper:brake()
    if self.last ~= nil and self.last > 0 then
        self:accelerate(self.last, 0)
        self:stop()
    end
end

-- 动态调整转速（无效）
function Stepper:speed(rpm)
    local freq = math.floor(self.freq * rpm / 60)
    -- pwm.setFreq(self.pwm, freq)
    self.pwm:setFreq(freq)
end

-- 停止
function Stepper:stop()
    log.info("stop")
    if self.running then
        -- pwm.stop(self.pwm)
        if self.pwm then
            self.pwm:stop()
        end
        self.last = 0
        self.running = false
        self:unlock()
    end
end

function Stepper:lock()
    self.en_pin:set(0)
end

function Stepper:unlock()
    self.en_pin:set(1)
end

local acc_interval = 10 -- 10ms加速一次

---执行加减速
---@param start integer 起始速度
---@param finish integer 结束速度
---@param count integer 脉冲数
---@return integer 加减速消耗的时间ms
---@return integer 加减速消耗的脉冲数
function Stepper:accelerate(start, finish, count)
    log.info(self.pwm, "accelerate start", start, "finish", finish, "count", count)

    local pulse = 0

    -- 至少1圈
    if count == 0 then
        count = self.freq
    end

    local step = math.floor(self.freq / 10)

    -- S加速曲线，缓起，缓停， t是0-1
    -- 速度公式 v = -2 * t^3 + 3 * t^2
    -- 加速度公式 a = -6 * t^2 + 6 * t
    local steps = math.floor(math.abs(finish - start) / step)
    log.info("accelerate step", step, "steps", steps)

    -- local speeds = {}
    for i = 1, steps, 1 do
        if not self.running then
            break
        end

        local t = i / steps
        local v = -2 * t * t * t + 3 * t * t -- 速度
        -- local a = -6 * t * t + 6 * t -- 加速度
        local vv = (finish - start) * v + start
        --log.info("accelerate", i, v, vv)
        vv = math.ceil(vv)

        -- 可能会出现0，导致死机，实时不会出现
        if vv == 0 then
            vv = 1
        end

        -- pwm.stop(self.pwm) -- PWM必须先停止再启动，否则无效
        -- pwm.setup(self.pwm, vv, 50, count)
        -- pwm.start(self.pwm)
        if self.pwm then
            self.pwm:stop()
        end
        local ret, pwm = iot.pwm(self.pwm_id, {
            freq = vv,
            duty = 50,
            count = count
        })
        if ret then
            self.pwm = pwm
            pwm:start()
        end


        iot.sleep(acc_interval)

        -- 累加脉冲数
        pulse = pulse + vv * acc_interval / 1000
    end

    log.info(tag, self.pul, "accelerate steps", steps, "pulses", pulse)

    return math.floor(steps * acc_interval), math.floor(pulse)
end

--- 计算 加速时间 和 圈数
function Stepper:calc_accelerate(start_rpm, finish_rpm)
    local start = math.floor(self.freq * start_rpm / 60)
    local finish = math.floor(self.freq * finish_rpm / 60)

    local step = math.floor(self.freq / 10)

    local pulse = 0
    local steps = math.floor(math.abs(finish - start) / step)

    for i = 1, steps, 1 do
        local t = i / steps
        local v = -2 * t * t * t + 3 * t * t -- 速度
        -- local a = -6 * t * t + 6 * t -- 加速度
        local vv = (finish - start) * v + start
        vv = math.ceil(vv)
        pulse = pulse + vv * acc_interval / 1000
    end
    return math.floor(steps * acc_interval), pulse / self.freq
end

return Stepper

