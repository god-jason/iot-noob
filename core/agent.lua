--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 消息代理，封装Link，阻塞执行，一问一答，方便主从模式编程
-- @module agent
local Agent = {}
Agent.__index = Agent

local tag = "Agent"

--- 创建询问器
-- @param link Link 连接实例
-- @param timeout integer 超时 ms
-- @return Agent
function Agent:new(link, timeout)
    local agent = setmetatable(link, self) --继承连接
    agent.timeout = timeout
    agent.asking = false
    return agent
end

--- 询问
-- @param request string 发送数据
-- @param len integer 期望长度
-- @return boolean 成功与否
-- @return string 返回数据
function Agent:ask(request, len)

    -- 重入锁，等待其他操作完成
    while self.asking do
        sys.wait(100)
    end
    self.asking = true

    -- log.info(tag, "ask", request, len)
    if request ~= nil and #request > 0 then
        local ret = self:write(request)
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
        local ret = self:wait(self.timeout)
        if not ret then
            log.error(tag, "read timeout")
            self.asking = false
            return false
        end

        local r, d = self:read()
        if not r then
            log.error(tag, "read failed")
            self.asking = false
            return false
        end
        buf = buf .. d
    until #buf >= len

    self.asking = false
    return true, buf
end


return Agent