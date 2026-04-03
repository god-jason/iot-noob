--- 智能场景
-- @module Scene
local Scene = {}
Scene.__index = Scene

local log = iot.logger("scene")
local devices = require("devices")
local cron = require("cron")
local agent = require("agent")

--- 场景实例化
function Scene:new(opts)
    local scene = setmetatable({
        name = opts.name or "-",
        delay = opts.delay or 0, -- 延迟时间s，避免突发变化
        ranges = opts.ranges or {}, -- 时间范围
        weekdays = opts.weekdays or {}, -- 限定星期
        triggers = opts.triggers or {}, -- 触发器
        is_and = opts.is_and or false, -- 条件关系 and/or
        conditions = opts.conditions or {}, -- 条件
        actions = opts.actions or {}, -- 响应
        triggered = false
    }, Scene)
    return scene
end

--- 场景打开
function Scene:open()

    -- 编译时间
    for k, range in ipairs(self.ranges) do
        if not range.start or not range.finish then
            return false, "需要起始和结束时间"
        end

        local h, m = range.start:match("(%d+):(%d+)")
        if h == nil or m == nil then
            return false, "时间格式 HH:mm, ec 06:00"
        end
        range._start = tonumber(h) * 60 + tonumber(m)

        h, m = range.finish:match("(%d+):(%d+)")
        if h == nil or m == nil then
            return false, "时间格式 HH:mm, ec 12:00"
        end
        range._finish = tonumber(h) * 60 + tonumber(m)
    end

    -- 编译条件
    for k, cond in ipairs(self.conditions) do
        if cond.type == "script" and type(cond.script) == "string" then
            local script = "return " .. cond.script
            local ret, info = load(script, "cond", "t", _G)
            if not ret then
                return false, info
            end
            cond.script = ret
        end
    end

    -- 编译响应
    for k, action in ipairs(self.actions) do
        if action.type == "script" and type(action.script) == "string" then
            local script = "return function()\n" .. action.script .. "\nend"
            local ret, info = load(script, "action", "t", _G)
            if not ret then
                return false, info
            end
            -- 返回闭包
            ret, info = pcall(ret)
            if not ret then
                return ret, info
            end
            action.script = info
        end
    end

    -- 注册触发器
    for i, trigger in ipairs(self.triggers) do
        if trigger.type == "time" then
            -- 每日启动
            local ret, info = cron.clock(trigger.time, function()
                self:execute()
            end, trigger.weekdays)

            if not ret then
                log.error(info)
                return false, info
            else
                trigger._cron = info
            end

        elseif trigger.type == "device" then
            -- 设备变化

            local device = devices[trigger.device]
            if device then
                trigger._cancel = device:on("change", function()
                    self:execute()
                end)
            else
                log.error("找不到设备", trigger.device)
                return false, "找不到设备" .. trigger.device
            end
        end
    end

    return true
end

--- 场景关闭
function Scene:close()
    -- 从计划任务注销
    for i, trigger in ipairs(self.triggers) do
        -- 取消定时
        if trigger._cron then
            cron.stop(trigger._cron)
        end
        -- 取消设备订阅
        if trigger._cancel then
            trigger._cancel()
        end
    end
    return true
end

--- 场景检查（内部用）
function Scene:check()
    local tm = os.date("*t")

    -- 检查星期范围
    if self.weekdays and #self.weekdays > 0 then
        local has = false
        for _, v in ipairs(self.weekdays) do
            if v == tm.wday then
                has = true
                break
            end
        end
        -- 星期不匹配
        if not has then
            return false
        end
    end

    -- 检查时间范围
    if self.ranges and #self.ranges > 0 then
        local hm = tm.hour * 60 + tm.min
        local ok = false
        for _, range in ipairs(self.ranges) do
            if range._start < range._finish and hm >= range._start and hm <= range._finish then
                -- 当天时间段
                ok = true
                break
            elseif range._start > range._finish and (hm >= range._finish or hm <= range._start) then
                -- 跨天时间段
                ok = true
                break
            end
        end
        if not ok then
            return false
        end
    end

    -- 检查条件
    if self.conditions and #self.conditions > 0 then
        local has = false
        for _, cond in ipairs(self.conditions) do
            if cond.type == "script" then
                local ok, ret = pcall(cond.script)
                if not ok then
                    log.error("条件计算错误", ret)
                    return false
                end
                if ret then
                    has = true
                elseif self.is_and then
                    return false
                end
            elseif cond.type == "device" then

                local device = devices[cond.device]
                if not device then
                    return false
                end

                -- 条件对比
                local ret, value = device:get_value(cond.key)
                if not ret then
                    return false, value
                end

                -- TODO 以下只能判断数据关系
                if type(value) ~= "number" then
                    log.error("device:", cond.device, " value:", cond.key, " is not a number")
                    return false
                end

                ret = false
                if cond.compare == ">" then
                    ret = value > tonumber(cond.value)
                elseif cond.compare == ">=" then
                    ret = value >= tonumber(cond.value)
                elseif cond.compare == "<" then
                    ret = value < tonumber(cond.value)
                elseif cond.compare == "<=" then
                    ret = value <= tonumber(cond.value)
                elseif cond.compare == "==" or cond.compare == "=" then
                    ret = value == tonumber(cond.value)
                elseif cond.compare == "~=" or cond.compare == "!=" or cond.compare == "<>" then
                    ret = value ~= tonumber(cond.value)
                else
                    log.error("不支持的比较方式", cond.compare)
                    return false
                end

                if ret then
                    has = true
                elseif self.is_and then
                    return false
                end
            end
        end

        -- 或 条件也全不满足
        if not has then
            return false
        end
    end

    return true
end

--- 场景执行（先检查条件，满足则执行响应）
function Scene:execute()

    -- 延迟处理，同时避免了快速重入
    if self.delay and self.delay > 0 then
        if self._timer then
            return
        end
        self._timer = iot.setTimeout(function()
            self._timer = nil
            self:execute()
        end, self.delay * 1000)
        return
    end

    -- 检查条件
    local ret = self:check()
    if not ret then
        self.triggered = false
        return
    end

    -- 已经触发，则不再执行
    if self.triggered then
        return
    end
    self.triggered = true

    -- 执行响应
    for _, action in ipairs(self.actions) do
        if action.type == "script" then
            -- 执行脚本
            local ok, err = pcall(action.script)
            if not ok then
                log.error("脚本错误", err)
            end
        elseif action.type == "device" then
            -- 修改变量
            local device = devices[action.device]
            if device then
                device:set(action.key, tonumber(action.value))
            else
                log.error("找不到设备", action.device)
            end
        elseif action.type == "scene" then
            -- 执行场景
            local scene = scenes[action.scene]
            if scene.__index == Scene and not scene.triggered then
                scene:execute()
            end
        elseif action.type == "action" then
            -- 执行响应
            local ok, err = agent.execute(action.action, action.data)
            if not ok then
                log.error("执行错误", err)
            end
        end
    end

end

return Scene
