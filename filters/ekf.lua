--- 扩展卡尔曼滤波器（工程稳定版）
-- @module ekf
local EKF = {}
EKF.__index = EKF

require("filters").register("ekf", EKF)

local log = iot.logger("ekf")

--======================
-- 基础矩阵工具
--======================

local function zeros(r, c)
    local m = {}
    for i = 1, r do
        m[i] = {}
        for j = 1, c do
            m[i][j] = 0
        end
    end
    return m
end

local function eye(n)
    local m = zeros(n, n)
    for i = 1, n do
        m[i][i] = 1
    end
    return m
end

local function matadd(A, B)
    local r, c = #A, #A[1]
    local C = zeros(r, c)
    for i = 1, r do
        for j = 1, c do
            C[i][j] = A[i][j] + B[i][j]
        end
    end
    return C
end

local function matsub(A, B)
    local r, c = #A, #A[1]
    local C = zeros(r, c)
    for i = 1, r do
        for j = 1, c do
            C[i][j] = A[i][j] - B[i][j]
        end
    end
    return C
end

local function matmul(A, B)
    local r, c, n = #A, #B[1], #B
    local C = zeros(r, c)
    for i = 1, r do
        for j = 1, c do
            local sum = 0
            for k = 1, n do
                sum = sum + A[i][k] * B[k][j]
            end
            C[i][j] = sum
        end
    end
    return C
end

local function transpose(A)
    local r, c = #A, #A[1]
    local T = zeros(c, r)
    for i = 1, r do
        for j = 1, c do
            T[j][i] = A[i][j]
        end
    end
    return T
end

--======================
-- 小矩阵求逆（稳定）
--======================

local function inv1(A)
    return {{1 / (A[1][1] + 1e-9)}}
end

local function inv2(A)
    local a, b = A[1][1], A[1][2]
    local c, d = A[2][1], A[2][2]

    local det = a * d - b * c
    if math.abs(det) < 1e-9 then
        return eye(2)
    end

    local inv_det = 1 / det

    return {
        { d * inv_det, -b * inv_det },
        { -c * inv_det, a * inv_det }
    }
end

local function inv(A)
    if #A == 1 then return inv1(A) end
    if #A == 2 then return inv2(A) end

    -- fallback（不推荐大矩阵）
    local n = #A
    local I = eye(n)
    local aug = {}

    for i = 1, n do
        aug[i] = {}
        for j = 1, n do
            aug[i][j] = A[i][j]
            aug[i][j+n] = I[i][j]
        end
    end

    for i = 1, n do
        local pivot = aug[i][i] or 1e-9
        for j = 1, 2*n do
            aug[i][j] = aug[i][j] / pivot
        end
        for k = 1, n do
            if k ~= i then
                local f = aug[k][i]
                for j = 1, 2*n do
                    aug[k][j] = aug[k][j] - f * aug[i][j]
                end
            end
        end
    end

    local res = zeros(n, n)
    for i = 1, n do
        for j = 1, n do
            res[i][j] = aug[i][j+n]
        end
    end
    return res
end

--======================
-- 安全函数
--======================

local function clamp(x)
    if x ~= x then return 0 end
    if x > 1e6 then return 1e6 end
    if x < -1e6 then return -1e6 end
    return x
end

--======================
-- 初始化
--======================

function EKF:new(opts)
    opts = opts or {}

    local obj = setmetatable({
        n = opts.state_dim,
        m = opts.meas_dim,

        x = zeros(opts.state_dim, 1),
        P = eye(opts.state_dim),

        Q = opts.Q or eye(opts.state_dim),
        R = opts.R or eye(opts.meas_dim),

        I = eye(opts.state_dim),

        f = opts.f,
        F = opts.F,
        h = opts.h,
        H = opts.H
    }, EKF)

    return obj
end

--======================
-- 预测
--======================

function EKF:predict(u)
    local F = self.F(self.x, u)
    self.x = self.f(self.x, u)

    local Ft = transpose(F)
    self.P = matadd(matmul(matmul(F, self.P), Ft), self.Q)
end

--======================
-- 更新（Joseph稳定）
--======================

function EKF:update(z)
    local H = self.H(self.x)

    local y = matsub(z, self.h(self.x))
    local Ht = transpose(H)

    local S = matadd(matmul(matmul(H, self.P), Ht), self.R)
    local Sinv = inv(S)

    local K = matmul(matmul(self.P, Ht), Sinv)

    -- 更新状态
    self.x = matadd(self.x, matmul(K, y))

    -- Joseph形式
    local KH = matmul(K, H)
    local I_KH = matsub(self.I, KH)
    local I_KH_t = transpose(I_KH)

    local KRKt = matmul(matmul(K, self.R), transpose(K))

    self.P = matadd(
        matmul(matmul(I_KH, self.P), I_KH_t),
        KRKt
    )

    -- 防发散
    for i = 1, self.n do
        self.x[i][1] = clamp(self.x[i][1])
    end
end

--[[
local ekf = EKF:new({
    state_dim = 2,
    meas_dim = 1,

    Q = {{0.01,0},{0,0.01}},
    R = {{1}},

    f = function(x, u)
        local dt = u.dt
        return {
            {x[1][1] + x[2][1]*dt},
            {x[2][1]}
        }
    end,

    F = function(x, u)
        local dt = u.dt
        return {
            {1, dt},
            {0, 1}
        }
    end,

    h = function(x)
        return {{x[1][1]}}
    end,

    H = function(x)
        return {{1, 0}}
    end
})

-- 使用
ekf:predict({dt = 1})
ekf:update({{10}})

]]--

return EKF