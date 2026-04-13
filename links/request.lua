--- 消息交互器，封装Link，阻塞执行，一问一答，方便主从模式编程
-- @module request
local Request = {}
Request.__index = Request

--local binary = require("binary")

local utils = require("utils")

local log = iot.logger("request")

local inc = utils.increment()

--- 创建询问器
-- abc
-- @param link Link 连接实例
-- @param timeout integer 超时 ms
-- @return Request
function Request:new(link, timeout)
    local request = setmetatable({}, self) -- 继承连接
    request.id = inc()
    request.link = link
    request.timeout = timeout or 1000
    request.requesting = false
    request.topic = "REQUEST_DATA_"..request.id
    request.cancel = link:on("data", function(data)
        iot.emit(request.topic, data)
    end)
    return request
end

--- 询问
-- @param request string 发送数据
-- @param want_len integer 期望长度
-- @return boolean 成功与否
-- @return string 返回数据
function Request:request(request, want_len)
    -- log.info("ask", binary.encodeHex(request), len)

    -- 重入锁，等待其他操作完成
    while self.requesting do
        log.info("等待其他请求完成")
        iot.sleep(200)
    end
    self.requesting = true

    -- 如果hub正在使用，等待解锁
    while self.link.hub and self.link.hub.using do
        log.info("等待HUB其他请求完成")
        iot.sleep(200)
    end

    -- log.info("ask", request, len)
    if request ~= nil and #request > 0 then
        local ret, err = self.link:write(request)
        if not ret then
            log.error("write failed", err)
            self.requesting = false
            return false, "写入失败"
        end
    end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    repeat
        -- 应该不是每次都要等待
        local ret, data = iot.wait(self.topic, self.timeout or 1000)
        if not ret then
            self.requesting = false
            return false, "读取超时"
        end
        buf = buf .. data
    until #buf >= want_len
    -- log.info("ask got", #buf, binary.encodeHex(buf))

    self.requesting = false
    return true, buf
end

return Request
