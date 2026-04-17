--- 保持器，可以用来维护网络连接
-- @module Keeper
local Keeper = require("utils").class()
local log = iot.logger("Keeper")

local id = 0

function Keeper:init()
    id = id + 1
    self.id = id
    self.msg = "KEEP_" .. self.id
    self.keeping = false
    self.timeout = self.timeout or 300 -- 默认5分钟

    iot.start(function()
        local tm = self.timeout * 1000
        while self.keeping do
            log.info(self.id, "wait", self.tm)
            local ret = iot.wait(self.msg, tm)
            if not ret then
                if self.callback then
                    iot.call(self.callback)
                end
            end
        end
    end)
end

--- 关闭看门狗
function Keeper:close()
    self.keeping = false
    iot.emit(self.msg)
end

--- 喂狗
function Keeper:feed()
    iot.emit(self.msg)
end

--[[
local keep = new Keeper({
    callback = function()
        mobile.flymode(0, true)
        mobile.flymode(0, true)
        iot.sleep(1000)
        mobile.flymode(1, false)
        mobile.flymode(1, false)
    end
})
]] --

return Keeper
