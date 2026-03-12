--- 位置式
-- @module PositionPid
local PositionPid = {}
PositionPid.__index = PositionPid

function PositionPid:realize(actual_val)
    -- 计算目标值与实际值的误差
    self.err = self.target_val - actual_val;

    -- 设定闭环死区 
    if self.err >= -20 and self.err <= 20 then
        self.err = 0
        self.integral = 0
    end

    self.integral = self.integral + self.err -- 误差累积

    -- PID算法实现
    self.actual_val = self.Kp * self.err + self.Ki * self.integral + self.Kd * (self.err - self.err_last);

    -- 误差传递
    self.err_last = self.err;

    -- 返回当前实际值
    return self.actual_val;
end

-- 位置式PID算法
function PositionPid:new(opts)
    opts = opts or {}
    return setmetatable({
        target_val = opts.target_val or 20, -- 目标值
        actual_val = opts.actual_val or 0, -- 实际值
        err = opts.err or 0, -- 偏差值
        err_last = opts.err_last or 0, -- 上一个偏差值
        Kp = opts.Kp or 0.045, -- 比例
        Ki = opts.Ki or 0.0, -- 积分
        Kd = opts.Kd or 0.0, -- 微分系数
        integral = opts.integral or 0 -- 积分值
    }, PositionPid)
end

return PositionPid
