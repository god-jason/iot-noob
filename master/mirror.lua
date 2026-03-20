--- 设备镜像
-- @module Mirror
local Mirror = {}
Mirror.__index = Mirror

function Mirror:new(dev1, dev2)
    local obj = setmetatable({
        dev1 = dev1,
        dev2 = dev2
    }, Mirror)
    obj:init()
    return obj
end

function Mirror:init()

    -- 订阅设备1的变化
    self.sub1 = self.dev1:on("change", function(values)
        -- 触发其他 change 监听
        self.dev2:put_values(values)

        -- 回写外设的寄存器
        iot.start(function()
            for k, v in pairs(values) do
                self.dev2:set(k, v)
            end
        end)
    end)

    -- 订阅设备2的变化
    self.sub2 = self.dev2:on("change", function(values)
        -- 触发其他 change 监听
        self.dev1:put_values(values)

        -- 回写外设的寄存器
        iot.start(function()
            for k, v in pairs(values) do
                self.dev1:set(k, v)
            end
        end)
    end)
end

--- 关闭
function Mirror:close()
    if self.sub1 then
        self.sub1()
        self.sub1 = nil
    end
    if self.sub2 then
        self.sub2()
        self.sub2 = nil
    end
end

return Mirror
