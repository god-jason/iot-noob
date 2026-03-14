--- 事件机制
-- @module Event
local Event = {}
Event.__index = Event

--- 初始化
function Event:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        handlers = {}
    }, Event)
    return obj
end

--- 订阅消息
-- @param name 名称
-- @param fn 回调
function Event:on(name, fn)
    if not self.handlers[name] then
        self.handlers[name] = {}
    end
    table.insert(self.handlers[name], {
        callback = fn
    })
    return function()
        Event:off(name, fn)
    end
end

--- 单次订阅
-- @param name 名称
-- @param fn 回调
function Event:once(name, fn)
    if not self.handlers[name] then
        self.handlers[name] = {}
    end
    table.insert(self.handlers[name], {
        once = true,
        callback = fn
    })
    return function()
        Event:off(name, fn)
    end
end

--- 取消订阅
-- @param name 名称
-- @param fn 回调，如果为空，则取消其全部订阅
function Event:off(name, fn)
    if not fn then
        self.handlers[name] = nil
        return
    end

    local list = self.handlers[name]
    if list then
        for i = #list, 1, -1 do
            if list[i].callback == fn then
                table.remove(list, i)
            end
        end
    end
end

--- 发送消息
-- @param name 名称
function Event:emit(name, ...)
    local list = self.handlers[name]
    if not list then
        return
    end
    -- 依次回调
    for i, v in ipairs(list) do
        pcall(v.callback, ...)
    end
    -- 删除once
    for i = #list, 1, -1 do
        if list[i].once then
            table.remove(list, i)
        end
    end
end

return Event
