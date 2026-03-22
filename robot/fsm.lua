--- 状态机
-- @module FSM
local FSM = {}
FSM.__index = FSM

local log = iot.logger("fsm")
local utils = require("utils")

-- 自增ID
local inc = utils.increment()

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
-- @param name 名称
-- @param state 状态 (需要有三个回调函数 enter, tick, leave)
function FSM:register(name, state)
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

    local ticked = false

    while self.running do

        -- 执行状态离开和进入
        if self.next_state then
            -- log.info(self.name, "enter", self.next_state)

            -- 执行离开
            if self.state and self.state.leave then
                log.info(self.name, "离开状态", self.state_name, self.state.name)

                -- self.state.leave(self)
                iot.call(self.state.leave, self.context)
            end

            -- 切换状态
            self.state_name = self.next_state
            self.state = self.states[self.next_state]
            self.next_state = nil

            -- 执行进入
            if self.state.enter then
                log.info(self.name, "进入状态", self.state_name, self.state.name)

                -- state.enter(self)
                iot.call(self.state.enter, self.context, table.unpack(self.next_args))
            end

            ticked = false
        end

        -- 执行状态tick任务
        if self.state then
            if self.state.tick then
                -- self.state.tick(self)
                -- 使用原始xpcall，避免错误日志上传多次
                local ret, info = xpcall(self.state.tick, iot.traceback, self.context)
                if ret == false then
                    log.error(info)

                    if not ticked then
                        iot.emit("error", info)
                    end
                end

                ticked = true
            end
        else
            log.error(self.name, "未设置状态")
        end

        -- iot.sleep(self.tick)
        local ret, info = iot.wait("fsm_" .. self.id .. "_break", self.tick)
        if ret then
            -- 被中断
            log.info(self.name, self.state_name, "break", info)
            -- break
        end
    end

    -- 执行离开
    if self.state and self.state.leave then
        log.info(self.name, "离开状态", self.state_name, self.state.name)
        -- self.state.leave(self)
        iot.call(self.state.leave, self.context)
    end

    -- 清理状态机
    self.running = false
end

--- 启动状态机
-- @param name 状态名
function FSM:start(name, ...)
    if self.running then
        log.error(self.name, self.state_name, "已经在执行")
        return false, "已经在执行"
    end

    -- 修改状态
    local ret, info = self:switch(name, ...)
    if not ret then
        return ret, info
    end

    -- 启动进程
    iot.start(FSM.execute, self)

    return true
end

--- 切换状态
-- @param name 状态名
function FSM:switch(name, ...)
    if not name then
        return false, "不能是空状态"
    end

    if self.state_name == name then
        return false, "已经进入状态" .. name
    end

    -- 加载新状态
    local state = self.states[name]
    if not state then
        return false, "未知状态" .. name
    end

    self.next_state = name
    self.next_args = {...}
    iot.emit("fsm_" .. self.id .. "_break", "切换状态")

    return true
end

--- 停止状态机
function FSM:stop()
    self.running = false
    iot.emit("fsm_" .. self.id .. "_break", "停止")
end

return FSM
