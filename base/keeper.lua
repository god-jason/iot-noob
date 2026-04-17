--- 保持器，可以用来维护网络连接
-- @module Keeper
local Keeper = require("utils").class()
local log = iot.logger("Keeper")

local id = 0

function Keeper:init()
    id = id + 1
    self.id = id
    self.msg = "KEEP_" .. self.id
    self._keeping = false
    self.timeout = self.timeout or 300 -- 默认5分钟

    self._times = 0 -- 超时次数
    self.fatal_times = self.fatal_times or 10
end

--- 打开看门狗
function Keeper:open()
    if self._keeping then
        return
    end
    self._keeping = true

    iot.start(function()
        log.info("start", self.id, self.timeout)
        local tm = self.timeout * 1000
        while self._keeping do
            log.info(self.id, "wait", tm)

            -- 等待喂狗
            local ret = iot.wait(self.msg, tm)
            if not ret then
                log.warn(self.id, "timeout")
                self._times = self._times + 1

                local cb = self.on_timeout

                -- 超时次数过多，使用更高级操作
                if self._times > self.fatal_times then
                    cb = self.on_fatal or cb
                    self._times = 0
                end

                -- 调用回调
                if cb then
                    iot.call(cb)
                end
            else
                self._times = 0
            end
        end
    end)
end

--- 关闭看门狗
function Keeper:close()
    self._keeping = false
    iot.emit(self.msg)
end

--- 喂狗
function Keeper:feed()
    iot.emit(self.msg)
    log.info(self.id, "feed")
end

--[[
local keep = new Keeper({
    on_timeout = function()
        mobile.flymode(0, true)
        mobile.flymode(0, true)
        iot.sleep(1000)
        mobile.flymode(1, false)
        mobile.flymode(1, false)
    end
})
]] --

return Keeper
