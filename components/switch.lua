local log = iot.logger("switch")

--- 组件 开关
-- @module Switch
local Switch = {}
Switch.__index = Switch

require("components").register("switch", Switch)

--- 初始化
function Switch:new(opts)
    opts = opts or {}
    local switch = setmetatable({
        pin = opts.pin,
        name = opts.name,
        reverse = opts.reverse or false,
        rising = opts.rising or false,
        falling = opts.falling or false,
        debounce = opts.debounce or 50,
        state = false,
        callback = opts.callback
    }, Switch)
    switch:init()
    return switch
end

function Switch:init()
    local this = self

    self.gpio = iot.gpio(self.pin, {
        rising = self.rising,
        falling = self.falling,
        debounce = self.debounce,
        callback = function(id, level)
            -- 反转
            if this.reverse then
                level = level > 0 and 0 or 1
            end

            self.state = (level == 1)

            log.info("switch", id, level, this.name)

            if this.disabled then
                return
            end

            -- 回调
            if type(self.callback) == "function" then
                self.callback(level)
            end

            -- 发送统一事件
            iot.emit("SWITCH", {
                pin = id,
                name = this.name,
                event = this.event,
                level = level
            })

            -- 发送特定事件
            if this.event and this.event ~= "" then
                iot.emit(this.event, level)
            end
        end
    })
end

--- 状态
function Switch:status()
    return self.state
end

--- 启用
function Switch:enable()
    log.info("enable", self.pin, self.name)
    self.disabled = false
end

--- 禁用
function Switch:disable()
    log.info("disable", self.pin, self.name)
    self.disabled = true
end

return Switch
