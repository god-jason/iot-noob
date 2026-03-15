--- 连接类定义
-- 所有连接必须继承Link，并实现标准接口
-- @module link
local Link = {}
Link.__index = Link

---  创建实例，子类定义可参考
-- @param obj table 连接对象
-- @return Link 对象
function Link:new(obj)
    local link = setmetatable(obj or {}, self)
    link._handlers = {}
    return link
end

---  打开
-- @return boolean
-- @return string error
function Link:open()
    return false, "Link open() 未实现"
end

---  关闭
function Link:close()
    return false, "Link close() 未实现"
end

---  读取数据
-- @return boolean 成功与否
-- @return string|error
function Link:read()
    return false, "Link read() 未实现"
end

---  写入数据
-- @param data string
-- @return boolean
-- @return error
function Link:write(data)
    return false, "Link write(data) 未实现"
end

--- 等待数据
-- @param timeout integer 超时 ms
-- @return boolean 成功与否
-- @return intger 长度
function Link:wait(timeout)
    return false, "Link wait(timeout) 未实现"
end

--- 开启透传
-- @param peer Link 对等连接
function Link:pipe(peer)
    self.peer = peer
end


--- 订阅消息
-- @param name 名称
-- @param fn 回调
function Link:on(name, fn)
    if not self._handlers[name] then
        self._handlers[name] = {}
    end
    table.insert(self._handlers[name], {
        callback = fn
    })
    return function()
        self:off(name, fn)
    end
end

--- 单次订阅
-- @param name 名称
-- @param fn 回调
function Link:once(name, fn)
    if not self._handlers[name] then
        self._handlers[name] = {}
    end
    table.insert(self._handlers[name], {
        once = true,
        callback = fn
    })
    return function()
        self:off(name, fn)
    end
end

--- 取消订阅
-- @param name 名称
-- @param fn 回调，如果为空，则取消其全部订阅
function Link:off(name, fn)
    if not fn then
        self._handlers[name] = nil
        return
    end

    local list = self._handlers[name]
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
function Link:emit(name, ...)
    local list = self._handlers[name]
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


return Link
