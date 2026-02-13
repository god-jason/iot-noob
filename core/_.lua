
function class(object)
    object.__index = object
end

function extend(child, parent)
    setmetatable(child, parent)
end

function new(class, object)
  return setmetatable(object or {}, class)
end

