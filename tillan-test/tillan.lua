local tillan = {}

local function can_cb(id, cb_type, param)
    if cb_type == can.CB_MSG then
        --log.info("有新的消息")

        local succ, id, id_type, rtr, data = can.rx(id)
        while succ do
            --log.info(mcu.x32(id), #data, data:toHex())

            -- 处理数据
            tillan.handle(id, data)

            -- 继续接收
            succ, id, id_type, rtr, data = can.rx(id)
        end

    elseif cb_type == can.CB_TX then
        if param then
            log.info("发送成功")
        else
            log.info("发送失败")
        end
    elseif cb_type == can.CB_ERR then
        log.info("CAN错误码", mcu.x32(param))
    elseif cb_type == can.CB_STATE then
        log.info("CAN新状态", param)
    end
end

local products = {}

function tillan.handle(id, data)

    local proto = id >> 26
    local type = (id >> 24) & 0x3
    local product_id = (id >> 16) & 0xff
    local device_id = (id >> 8) & 0xff
    local param_id = id & 0xff

    -- local _, seq, ok = pack.unpack(data, "c2")

    local product = tillan.load_product(product_id)
    if product == nil then
        log.info("未知产品", product_id)
        return
    end

    local point = product.indexed_points[param_id]
    if point == nil then
        log.info("未知点位", product_id, param_id)
        return
    end

    local seq, ok, val

    if point.type == "s8" then
        _, seq, ok, _, val = pack.unpack(data, "b2A3c")
    elseif point.type == "u8" then
        _, seq, ok, _, val = pack.unpack(data, "b2A3c")
    elseif point.type == "s16" then
        _, seq, ok, _, val = pack.unpack(data, "b2A2>h")
    elseif point.type == "u16" then
        _, seq, ok, _, val = pack.unpack(data, "b2A2>H")
    elseif point.type == "s32" then
        _, seq, ok, val = pack.unpack(data, "b2>i")
    elseif point.type == "u32" then
        _, seq, ok, val = pack.unpack(data, "b2>I")
    else
        log.info("未知点位类型", product_id, param_id, point.type)
        return
    end

    -- 倍率
    if val ~= 0 and point.rate ~= nil and point.rate ~= 1 and point.rate ~= 0 then
        val = val / point.rate
    end

    log.info("获取到数据：", seq, ok, product.name or product_id, device_id, point.desc or point.id, val)

end

function tillan.load_product(id)
    local product = products[id]
    if product == nil then
        local path = "/luadb/tillan-" .. id .. ".json"
        local data = io.readFile(path)

        log.info("加载产品", id, path)

        products[id] = false -- 避免再次加载

        if data == nil then
            return false
        end

        -- 解析
        local prod, ret, err = json.decode(data)
        if not ret then
            log.info("解析产品错误", err)
            return false
        end

        products[id] = prod

        prod.indexed_points = {}

        -- 索引
        for i, p in ipairs(prod.points) do
            prod.indexed_points[p.id] = p
        end

        return prod
    elseif product == false then
        return nil
    else
        return product
    end
end

function tillan.init()
    -- 打开can口
    local ret = can.init(0, 128)
    log.info("can.init ret", ret)

    can.on(0, can_cb)

    ret = can.timing(0, 100000, 6, 6, 3, 2)
    log.info("can.timing ret", ret)

    can.filter(0, false, 0xffffffff, 0xffffffff) -- 不过滤，全显示
    log.info("can.filter ret", ret)

    ret = can.mode(0, can.MODE_NORMAL)
    log.info("can.mode ret", ret)
end

function tillan.send()

end

return tillan
