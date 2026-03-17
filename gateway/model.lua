--- 物模型管理
-- @module model
local model = {}

local log = iot.logger("model")

local database = require("database")

local cache = {}

--- 获得物模型
-- @param product_id string
-- @return table
function model.get(product_id)
    if cache[product_id] then
        return cache[product_id]
    end

    log.info("load 物模型", product_id)
    local mod = database.get("model", "id", product_id)
    if mod then
        cache[product_id] = mod
    end
    return mod
end

function model.clear()
    cache = {}
end

return model
