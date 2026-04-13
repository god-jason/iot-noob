--- 组件基础类定义
-- 组件都必须继承Component，并实现标准接口
-- @module device
local Component = require("utils").class(require("event"))

local log = iot.logger("Component")

function Component:init()
    -- log.info("init")
    -- 初始化默认参数
end

---  设置值 需要继承
-- @param key string 键
-- @param value any 值
-- @return boolean 成功与否
-- @return string 错误信息
function Component:set(key, value)
    return false, "当前组件不支持set操作"
end

---  读取值 需要继承
-- @param key string 键
-- @return boolean 成功与否
-- @return any 值
function Component:get(key)
    return false, "当前组件不支持get操作"
end

return Component
