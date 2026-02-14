local tag = "servo"

local Servo = {}
Servo.__index = Servo

--- 创建伺服电机
---@param pul integer PWM号
---@param dir integer 方向引脚
---@param reverse boolean 电机反转（适用于接线装反的场景）
---@param en integer 使能引脚
---@param freq integer  基础频率(一周的脉冲数)
---@param smooth boolean 平滑过渡
function Servo:new(opts)
    local servo = setmetatable(opts, Servo)
    servo:init()
    return servo
end

-- 初始化
function Servo:init()
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
function Servo:start(rpm, rounds)
    log.info(tag, self.pul, "start rpm", rpm, "rounds", rounds)
    -- if self.running then
    --     -- 电机驱动必须先把PWM停下，再修改频率才有效
    --     --pwm.stop(self.pul)
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

    log.info(tag, self.pul, "start freq", freq, "count", count)

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

    log.info(tag, self.pul, "start", freq, "count", count)
    local time = math.floor(count / freq * 1000)

    -- 匀速运行
    pwm.stop(self.pul)
    if freq > 0 and count > 0 then
        pwm.setup(self.pul, freq, 50, count)
        pwm.start(self.pul)
    end
    return time
end

-- 刹车（至零）
function Servo:brake()
    if self.last ~= nil and self.last > 0 then
        self:accelerate(self.last, 0)
        self:stop()
    end
end

-- 动态调整转速（无效）
function Servo:speed(rpm)
    local freq = math.floor(self.freq * rpm / 60)
    pwm.setFreq(self.pul, freq)
end

-- 停止
function Servo:stop()
    log.info(tag, "stop")
    if self.running then
        pwm.stop(self.pul)
        self.last = 0
        self.running = false
        self:unlock()
    end
end

function Servo:lock()
    self.en_pin:set(0)
end

function Servo:unlock()
    self.en_pin:set(1)
end

local acc_interval = 10 -- 10ms加速一次

---执行加减速
---@param start integer 起始速度
---@param finish integer 结束速度
---@param count integer 脉冲数
---@return integer 加减速消耗的时间ms
---@return integer 加减速消耗的脉冲数
function Servo:accelerate(start, finish, count)
    log.info(tag, self.pul, "accelerate start", start, "finish", finish, "count", count)

    local pulse = 0

    if count == 0 then
        count = self.freq
    end

    local step = math.floor(self.freq / 100)

    -- S加速曲线，缓起，缓停， t是0-1
    -- 速度公式 v = -2 * t^3 + 3 * t^2
    -- 加速度公式 a = -6 * t^2 + 6 * t
    local tm = math.abs(finish - start) / step
    -- log.info("accelerate tm", tm)
    -- local speeds = {}
    local i = acc_interval -- 跳过初始和结束速度
    while i < tm and self.running do
        -- .info("accelerate interval", i)

        local t = i / tm
        local v = -2 * t * t * t + 3 * t * t -- 速度
        -- local a = -6 * t * t + 6 * t -- 加速度
        local vv = (finish - start) * v + start
        vv = math.floor(vv)

        --log.info("accelerate interval", i, vv)

        -- 可能会出现0，导致死机
        if vv == 0 then
            break
        end

        -- table.insert(speeds, vv)
        i = i + acc_interval -- 10ms加速一次

        pwm.stop(self.pul) -- PWM必须先停止再启动，否则无效
        pwm.setup(self.pul, vv, 50, count)
        pwm.start(self.pul)

        iot.sleep(acc_interval)

        -- 累加脉冲数
        pulse = pulse + vv * acc_interval / 1000
    end

    log.info(tag, self.pul, "accelerate time", tm, "pulses", pulse)

    return math.floor(tm), math.floor(pulse)
end

--- 计算 加速时间 和 圈数
function Servo:calc_accelerate(start_rpm, finish_rpm)
    local start = math.floor(self.freq * start_rpm / 60)
    local finish = math.floor(self.freq * finish_rpm / 60)

    local step = math.floor(self.freq / 100)

    local pulse = 0
    local tm = math.abs(finish - start) / step
    local i = acc_interval -- 跳过初始和结束速度
    while i < tm do
        local t = i / tm
        local v = -2 * t * t * t + 3 * t * t -- 速度
        -- local a = -6 * t * t + 6 * t -- 加速度
        local vv = (finish - start) * v + start
        vv = math.floor(vv)
        i = i + acc_interval
        pulse = pulse + vv * acc_interval / 1000
    end
    return math.floor(tm), pulse / self.freq
end

return Servo

