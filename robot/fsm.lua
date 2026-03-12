local log = iot.logger("fsm")

local utils = require("utils")

-- 自增ID
local inc = utils.increment()

--- 状态机
-- @module FSM
local FSM = {}
FSM.__index = FSM

--- 创建状态机
function FSM:new(opts)
    opts = opts or {}
    return setmetatable({
        id = inc(),
        name = opts.name or "FSM",
        tick = opts.tick or 1000,
        state = nil,
        states = {},
        context = {}
    }, FSM)
end

--- 注册状态
-- @param string name 名称
-- @param table state 状态 (需要有三个回调函数 enter, tick, leave)
function FSM:register(name, state)
    -- self.states[name] = state    
    if type(name) == "string" and type(state) == "table" then
        self.states[name] = state
    end

    -- 批量注册
    if type(name) == "table" then
        for k, v in pairs(name) do
            if type(v) == "table" then
                self.states[k] = v
            end
        end
    end
end

--- 克隆状态机
function FSM:clone()
    return setmetatable({
        id = inc(),
        name = self.name,
        tick = self.tick,
        state = nil,
        states = self.states,
        context = {}
    }, FSM)
end

--- 执行（内部用）
function FSM:execute()
    self.running = true

    while self.running do

        -- 执行状态离开和进入
        if self.next_state then
            -- 执行离开
            if self.state and self.state.leave then
                -- self.state.leave(self)
                local ret, info = pcall(self.state.leave, self.context)
                if not ret then
                    log.error(self.name, self.state_name, "执行leave错误", info)
                end
            end

            -- 切换状态
            self.state_name = self.next_state
            self.state = self.states[self.next_state]
            self.next_state = nil

            -- 执行进入
            if self.state.enter then
                -- state.enter(self)
                local ret, info = pcall(self.state.enter, self.context)
                if not ret then
                    log.error(self.name, self.state_name, "执行enter错误", info)
                end
            end
        end

        -- 执行状态tick任务
        if self.state then
            if self.state.tick then
                -- self.state.tick(self)
                local ret, info = pcall(self.state.tick, self.context)
                if not ret then
                    log.error(self.name, self.state_name, "执行tick错误", info)
                end
            end
        else
            log.error(self.name, "未设置状态")
        end

        -- iot.sleep(self.tick)
        local ret, info = iot.wait("fsm_" .. self.id .. "_break", self.tick)
        if ret then
            -- 被中断
            log.info(self.name, self.state_name, "被中断", info)
            -- break
        end
    end

    -- 执行离开
    if self.state and self.state.leave then
        -- self.state.leave(self)
        local ret, info = pcall(self.state.leave, self.context)
        if not ret then
            log.error(self.name, self.state_name, "执行leave错误", info)
        end
    end

    -- 清理状态机
    self.running = false
end

--- 启动状态机
function FSM:start(name)
    if self.running then
        log.error(self.name, self.state_name, "已经在执行")
        return false, "已经在执行"
    end

    -- 修改状态
    local ret, info = self:set(name)
    if not ret then
        return ret, info
    end

    -- 启动进程
    iot.start(FSM.execute, self)

    return true
end

--- 切换状态
function FSM:set(name)
    if not name then
        return false, "空状态"
    end

    -- 加载新状态
    local state = self.states[name]
    if not state then
        return false, "未知状态" .. name
    end

    self.next_state = name
    iot.emit("fsm_" .. self.id .. "_break")

    return true
end

--- 停止状态机
function FSM:stop()
    self.running = false
    iot.emit("fsm_" .. self.id .. "_break")
end

return FSM
