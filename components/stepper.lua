--- 组件 步进电机
-- @module Stepper
local Stepper = require("utils").class(require("component"))

require("components").register("stepper", Stepper)

local log = iot.logger("Stepper")

--- 创建步进电机
-- @param opts 参数
--  opts.id integer PWM号
--  opts.dir integer 方向引脚
--  opts.reverse boolean 电机反转（适用于接线装反的场景）
--  opts.en integer 使能引脚
--  opts.freq integer  基础频率(一周的脉冲数)
--  opts.smooth boolean 平滑过渡 注意！！！开启平滑之后，正常行走脉冲会多发，需要手动停止或刹车
function Stepper:init(opts)
    self.pwm_id = self.pwm_id
    self.dir = self.dir
    self.en = self.en
    self.reverse = self.reverse or false
    self.freq = self.freq or 16000
    self.smooth = self.smooth or false
    self.running = false
    self.rounds = 0
    self.last = 0

    self.running = false
    self.dir_pin = iot.gpio(self.dir)
    self.en_pin = iot.gpio(self.en)

    -- 默认使用低电平有效的驱动器
    self.en_pin:set(1)
end

--- 运行（转速，圈数）
-- @param rpm number 转速
-- @param rounds number 圈数
-- @param no_accelerate boolean 不加速
-- @return integer 需要等待时间ms
function Stepper:start(rpm, rounds, no_accelerate)
    log.info(self.pwm_id, "启动 rpm", rpm, "rounds", rounds)
    -- if self.running then
    --     -- 电机驱动必须先把PWM停下，再修改频率才有效
    --     --pwm.stop(self.pwm)
    -- end

    -- 记录圈数
    self.rounds = rounds
    self.running = true

    self:emit("change", {
        rpm = rpm,
        rounds = rounds,
        running = true
    })

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

    -- 加减速
    if self.smooth and not no_accelerate then
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

    log.info(self.pwm_id, "start freq", freq, "count", count)
    local time = math.ceil(count / freq * 1000)

    -- 先停止再改速
    -- pwm.stop(self.pwm_id)
    if self.pwm then
        self.pwm:stop()
        self.pwm = nil
    end

    if freq > 0 and count > 0 then
        -- pwm.setup(self.pwm_id, freq, 50, count)
        -- pwm.start(self.pwm_id)
        local ret, pwm = iot.pwm(self.pwm_id, {
            freq = freq,
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

--- 刹车（至零）
function Stepper:brake()
    log.info(self.pwm_id, "brake")
    if self.smooth and self.last > 0 then
        self:accelerate(self.last, 0)
    end
    self:stop()
end

--- 动态调整转速（无效，驱动器不支持直接改变频率）
function Stepper:speed(rpm)
    local freq = math.floor(self.freq * rpm / 60)
    -- pwm.setFreq(self.pwm_id, freq)
    self.pwm:setFreq(freq)
end

--- 停止
function Stepper:stop()
    log.info(self.pwm_id, "stop")
    if self.running then
        -- pwm.stop(self.pwm_id)
        if self.pwm then
            self.pwm:stop()
            self.pwm = nil
        end

        self.rounds = 0
        self.last = 0
        self.running = false
        self:unlock()

        self:emit("change", {
            rpm = 0,
            rounds = 0,
            running = false
        })
    end
end

--- 锁机
function Stepper:lock()
    log.info(self.pwm_id, "lock")
    self.en_pin:set(0)

    self:emit("change", {
        lock = true
    })
end

--- 解锁
function Stepper:unlock()
    log.info(self.pwm_id, "unlock")
    self.en_pin:set(1)

    self:emit("change", {
        lock = false
    })
end

-- TODO 放参数里
local acc_interval = 10 -- 10ms加速一次

---执行加减速
-- @param start integer 起始速度
-- @param finish integer 结束速度
-- @param count integer 脉冲数
-- @return integer 加减速消耗的时间ms
-- @return integer 加减速消耗的脉冲数
function Stepper:accelerate(start, finish, count)
    if start < finish then
        log.info(self.pwm_id, "加速 start", start, "finish", finish, "count", count)
    else
        log.info(self.pwm_id, "减速 start", start, "finish", finish, "count", count)
    end

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
    log.info("步长 step", step, "steps", steps)

    -- local speeds = {}
    for i = 1, steps, 1 do
        if not self.running then
            break
        end

        local t = i / steps
        local v = -2 * t * t * t + 3 * t * t -- 速度
        -- local a = -6 * t * t + 6 * t -- 加速度
        local vv = (finish - start) * v + start
        vv = math.ceil(vv)

        -- log.info("accelerate", i, vv)

        -- 可能会出现0，导致死机，实时不会出现
        if vv == 0 then
            vv = 1
        end

        -- pwm.stop(self.pwm_id) -- PWM必须先停止再启动，否则无效
        -- pwm.setup(self.pwm_id, vv, 50, count)
        -- pwm.start(self.pwm_id)
        if self.pwm then
            self.pwm:stop()
            self.pwm = nil
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

    -- log.info(tag, self.pul, "accelerate steps", steps, "pulses", pulse)
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

--- 设置值
function Stepper:set(key, value)
    if key == "freq" then
        self.freq = value
    elseif key == "smooth" then
        self.smooth = value
    else
        return false, "Stepper组件不支持变量：" .. key
    end
    return true
end

function Stepper:get(key)
    if key == "freq" then
        return true, self.freq
    elseif key == "smooth" then
        return true, self.smooth
    elseif key == "rounds" then
        return true, self.rounds
    elseif key == "running" then
        return true, self.running
    else
        return false, "Stepper组件不支持变量：" .. key
    end
end


return Stepper

