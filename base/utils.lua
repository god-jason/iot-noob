--- 工具集
-- @module utils
local utils = {}

--- 深度克隆
-- @param obj table
-- @return table
function utils.deep_clone(obj)
    if type(obj) ~= "table" then
        return obj
    end
    local new = {}
    for k, v in pairs(obj) do
        new[k] = utils.deep_clone(v)
    end
    return new
end

--- 合并
-- @param t1 table
-- @param t2 table
-- @return table
function utils.merge(t1, t2)
  for k,v in pairs(t2) do
      t1[k] = v
  end
  return t1
end

--- 自动
-- @return function 自增闭包
function utils.increment()
    local id = 0
    return function()
        id = id + 1
        return id
    end
end


return utils