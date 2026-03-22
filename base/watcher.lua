--- 观察器
-- @module Watcher
local Watcher = {}
Watcher.__index = Watcher

local utils = require("utils")
local log = iot.logger("watcher")

--- 实例化
function Watcher:new()
    return setmetatable({
        inc = utils.increment(),
        watchers = {}
    }, Watcher)
end

--- 订阅
-- @param cb function 回凋
-- @return integer 订阅ID
function Watcher:watch(cb)
    local id = self.inc()
    self.watchers[id] = cb
    return id
end

--- 取消
function Watcher:unwatch(id)
    self.watchers[id] = nil
end

--- 清空
function Watcher:clear()
    self.watchers = {}
end

--- 派发
function Watcher:dispatch(...)
    for i, cb in pairs(self.watchers) do
        if cb then
            iot.xcall(cb, ...)
        end
    end
end

return Watcher
