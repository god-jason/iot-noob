--- 模块功能：产品管理
-- @module product
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30

module(..., package.seeall)

local MOD = "PRODUCT"

require "fs"

local MOD = "PRODUCT"
local root = "/noob/product/"

-- 产品配置文件根目录
if not fs.exists(root) then
    fs.makeDir(root) -- 自动创建
end

local products = {}

-- 加载产品
function load()
    product = {} -- 清空
    local fs = fs.list(root, 0, 9999)
    for i, f in ipairs(fs) do
        if f.type ~= "folder" then
            local content = fs.read(root .. f.name)
            products[f.name] = json.decode(content)
        end
    end
end

-- 默认加载
load()

-- 产品配置示例
local temperatureSensor = {
    id = "temperature",
    name = "温湿度传感器",
    -- 映射表
    mappers = {
        {
            code = 3,
            addr = 0,
            size = 2,
            points = {
                {
                    type = "uint16",
                    name = "temperature",
                    offset = 0,
                    be = true,
                    rate = 0.1
                },
                {
                    type = "uint16",
                    name = "humidity",
                    offset = 1,
                    be = true,
                    rate = 0.1
                }
            }
        }
    },
    -- 过滤器
    filters = {
        {name = "temperature", expression = "temperature < 120"},
        {name = "temperature", expression = "temperature > -40"}
    },
    -- 计算器
    calculators = {{name = "fahrenheit", expression = "32 + temperature * 1.8"}}
}
