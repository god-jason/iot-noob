
local EKF = {}
EKF.__index = EKF

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
    local r = #A
    local c = #A[1]
    local C = zeros(r, c)

    for i = 1, r do
        for j = 1, c do
            C[i][j] = A[i][j] + B[i][j]
        end
    end

    return C
end

local function matsub(A, B)
    local r = #A
    local c = #A[1]
    local C = zeros(r, c)

    for i = 1, r do
        for j = 1, c do
            C[i][j] = A[i][j] - B[i][j]
        end
    end

    return C
end

local function transpose(A)

    local r = #A
    local c = #A[1]

    local T = zeros(c, r)

    for i = 1, r do
        for j = 1, c do
            T[j][i] = A[i][j]
        end
    end

    return T
end

local function matmul(A, B)

    local r = #A
    local c = #B[1]
    local n = #B

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

-- 矩阵求逆 (高斯消元)
local function inv(A)

    local n = #A
    local I = eye(n)

    local aug = {}

    for i = 1, n do
        aug[i] = {}
        for j = 1, n do
            aug[i][j] = A[i][j]
            aug[i][j + n] = I[i][j]
        end
    end

    for i = 1, n do

        local pivot = aug[i][i]

        for j = 1, 2 * n do
            aug[i][j] = aug[i][j] / pivot
        end

        for k = 1, n do
            if k ~= i then

                local factor = aug[k][i]

                for j = 1, 2 * n do
                    aug[k][j] = aug[k][j] - factor * aug[i][j]
                end
            end
        end
    end

    local res = zeros(n, n)

    for i = 1, n do
        for j = 1, n do
            res[i][j] = aug[i][j + n]
        end
    end

    return res
end

-- EKF 初始化
function EKF:new(state_dim, meas_dim)

    local obj = {}

    obj.state_dim = state_dim
    obj.meas_dim = meas_dim

    obj.x = zeros(state_dim, 1)
    obj.P = eye(state_dim)

    obj.Q = eye(state_dim)
    obj.R = eye(meas_dim)

    obj.I = eye(state_dim)

    setmetatable(obj, self)

    return obj
end

-- 预测
function EKF:predict(f_func, F_jacobian, u)

    local F = F_jacobian(self.x, u)

    self.x = f_func(self.x, u)

    local Ft = transpose(F)

    self.P = matadd(matmul(matmul(F, self.P), Ft), self.Q)
end

-- 更新
function EKF:update(z, h_func, H_jacobian)

    local H = H_jacobian(self.x)

    local y = matsub(z, h_func(self.x))

    local Ht = transpose(H)

    local S = matadd(matmul(matmul(H, self.P), Ht), self.R)

    local K = matmul(matmul(self.P, Ht), inv(S))

    self.x = matadd(self.x, matmul(K, y))

    local KH = matmul(K, H)

    self.P = matmul(matsub(self.I, KH), self.P)
end

-- 示例
local function example()

    local ekf = EKF:new(2, 1)

    ekf.Q = {{0.01, 0}, {0, 0.01}}
    ekf.R = {{1}}

    -- 状态函数
    local function f(x, u)

        local dt = u.dt

        return {{x[1][1] + x[2][1] * dt}, {x[2][1]}}
    end

    -- Jacobian
    local function F(x, u)

        local dt = u.dt

        return {{1, dt}, {0, 1}}
    end

    -- 观测函数
    local function h(x)

        return {{x[1][1]}}
    end

    -- 观测Jacobian
    local function H(x)

        return {{1, 0}}
    end

    for i = 1, 20 do

        local z = {{i + math.random() * 0.5}}

        ekf:predict(f, F, {
            dt = 1
        })

        ekf:update(z, h, H)

        print("pos", ekf.x[1][1], "vel", ekf.x[2][1])
    end

end

return EKF
