--- 消息代理，封装Link，阻塞执行，一问一答，方便主从模式编程
-- 物联小白标准库，非授权禁止商业使用
-- Author 杰神
-- License GPLv3
-- Copyright 南京本易物联网有限公司@2025
--
-- @module agent
local Agent = {}
Agent.__index = Agent

local binary = require("binary")

local tag = "Agent"

--- 创建询问器
-- abc
-- @param link Link 连接实例
-- @param timeout integer 超时 ms
-- @return Agent
function Agent:new(link, timeout)
    local agent = setmetatable({}, self) -- 继承连接
    agent.link = link
    agent.timeout = timeout or 1000
    agent.asking = false
    return agent
end

--- 询问
-- @param request string 发送数据
-- @param len integer 期望长度
-- @return boolean 成功与否
-- @return string 返回数据
function Agent:ask(request, len)
    -- log.info(tag, "ask", binary.encodeHex(request), len)

    -- 重入锁，等待其他操作完成
    while self.asking do
        sys.wait(100)
    end
    self.asking = true

    -- log.info(tag, "ask", request, len)
    if request ~= nil and #request > 0 then
        local ret = self.link:write(request)
        if not ret then
            log.error(tag, "write failed")
            self.asking = false
            return false
        end
    end

    -- 解决分包问题
    -- 循环读数据，直到读取到需要的长度
    local buf = ""
    repeat
        -- 应该不是每次都要等待
        local ret = self.link:wait(self.timeout)
        if not ret then
            log.error(tag, "read timeout")
            self.asking = false
            return false
        end

        local r, d = self.link:read()
        if not r then
            log.error(tag, "read failed")
            self.asking = false
            return false
        end
        buf = buf .. d
    until #buf >= len

    -- log.info(tag, "ask got", #buf, binary.encodeHex(buf))

    self.asking = false
    return true, buf
end

return Agent
