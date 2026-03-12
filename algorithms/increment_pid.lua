--- 增量式PID算法
-- @module IncrementPid
local IncrementPid = {}
IncrementPid.__index = IncrementPid

function IncrementPid:realize(temp_val)
    -- 传入目标值
    self.target_val = temp_val;

    -- 计算目标值与实际值的误差
    self.err = self.target_val - self.actual_val;

    -- PID算法实现
    local increment_val = self.Kp * (self.err - self.err_next) + self.Ki * self.err + self.Kd *
                              (self.err - 2 * self.err_next + self.err_last);

    -- 累加
    self.actual_val = self.actual_val + increment_val;

    -- 传递误差
    self.err_last = self.err_next;
    self.err_next = self.err;

    -- 返回当前实际值
    return self.actual_val;
end

function IncrementPid:new(opts)
    opts = opts or {}
    return setmetatable({
        target_val = opts.target_val or 0, -- 目标值
        actual_val = opts.actual_val or 0, -- 实际值
        err = opts.err or 0, -- 偏差值
        err_last = opts.err_last or 0, -- 上一个偏差值
        Kp = opts.Kp or 0.2, -- 比例
        Ki = opts.Ki or 0.8, -- 积分
        Kd = opts.Kd or 0.01, -- 微分系数
        integral = opts.integral or 0 -- 积分值
    }, IncrementPid)
end

return IncrementPid
