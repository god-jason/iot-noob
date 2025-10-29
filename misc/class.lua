
function new(class, obj)
  obj = obj or {}
  setmetatable(obj, { __index = class })
  return obj    
end

function extend(child, parent)
  setmetatable(child, { __index = parent })
  return child    
end 

