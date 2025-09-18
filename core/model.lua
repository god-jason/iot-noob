--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025

--- 物模型管理
-- @module model
local model = {}

local tag = "model"

local database = require("database")

local catch = {}

--- 获得物模型
-- @param product_id string
-- @return table
function model.get(product_id)
    if catch[product_id] then
        return catch[product_id]
    end

    log.info(tag, "load model", product_id)
    local mod = database.get("model", "id", product_id)
    if mod then
        catch[product_id] = mod
    end
    return mod
end

return model
