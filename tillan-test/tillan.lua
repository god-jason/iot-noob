local tillan = {}

local cloud = require("cloud")

local products = {}
local devices = {}

--[[ 数据结构定义

devices = Map<key, Device>
key = product_id + "-" + device_id

class Device {
  id: string 设备ID，最终入库
  update: timestamp 更新时间
  values: Map<key, Value> 值
  changes: Map<key, Value> 变化的值
}

class Value {
  time: timestamp 更新时间戳
  value: any 最终值
}

]]

local function load_product(id)
    local product = products[id]
    if product == nil then
        local path = "/luadb/tillan-" .. id .. ".json"
        local data = io.readFile(path)

        log.info("加载产品", id, path)

        products[id] = false -- 避免再次加载

        if data == nil then
            return nil
        end

        -- 解析
        local prod, ret, err = json.decode(data)
        if not ret then
            log.info("解析产品错误", err)
            return nil
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

local function set_device_value(device, key, val, time)
    local value = device.values[key]
    if value == nil then
        value = {
            time = time,
            value = val
        }
        device.values[key] = value
    end

    value.time = time
    if value.value ~= val then
        value.value = val
        device.changes[key] = value -- 加入修改
        device.changed = true
    end

    device.update = time
end

local function handle_can(id, data)

    local proto = (id >> 26)
    local type = (id >> 24) & 0x3
    local product_id = (id >> 16) & 0xff
    local device_id = (id >> 8) & 0xff
    local param_id = id & 0xff

    -- log.info("message", id, proto, type, product_id, device_id, param_id)
    if type ~= 3 then
        return -- 只处理数据上报
    end

    -- TODO 是否要使用平台最终ID，或SN
    local dev_id = product_id .. "-" .. device_id
    local device = devices[dev_id]
    if device == nil then
        device = {
            id = "xxxx",
            update = os.time(),
            values = {}, -- 数据
            changes = {}, -- 变化数据
            changed = false
        }
        devices[dev_id] = device
    end

    -- local _, seq, ok = pack.unpack(data, "c2")

    local product = load_product(product_id)
    if product == nil then
        log.info("未知产品", product_id)
        return
    end

    local point = product.indexed_points[param_id]
    if point == nil then
        log.info("未知点位", product_id, param_id)
        return
    end

    local time = os.time()

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
    elseif point.type == "hex" then
        val = string.sub(data, 3)
        val = string.toHex(data, val)
        -- elseif point.type == "bits" then
        --     -- 位类型，特殊处理

        --     _, seq, ok, val = pack.unpack(data, "b2>I")
        --     for i, b in ipairs(point.bits) do
        --         -- local bit = val & (0x1 << b.bit) > 0
        --         local bit = (val >> b.bit) & 0x1 --使用 0 1 代表bool
        --         set_device_value(device, b.name, bit, time)
        --     end

        --     device.update = time
        --     return
    elseif point.type == "bits" then
        -- val = string.sub(data, 3)
        _, seq, ok, val = pack.unpack(data, "b2>I")

        for i, p in ipairs(point.bits) do
            local size = p.size or 1
            local v = (val >> p.bit) & (0x1 << size - 1)

            -- 倍率
            if size > 1 then
                if p.rate ~= nil and p.rate ~= 1 and p.rate ~= 0 then
                    val = val / p.rate
                end    
            end
            
            set_device_value(device, p.name, v, time)
        end

        return
    else
        log.info("未知点位类型", product_id, param_id, point.type)
        return
    end

    -- 倍率
    if point.rate ~= nil and point.rate ~= 1 and point.rate ~= 0 then
        val = val / point.rate
    end

    set_device_value(device, point.name, val, time)

    -- 只在调试时打开，否则日志太多
    log.info("获取到数据：", seq, ok, product.name or product_id, device_id, point.desc or point.id, val)

end

local function can_cb(id, cb_type, param)
    if cb_type == can.CB_MSG then
        -- log.info("有新的消息")

        local succ, id, id_type, rtr, data = can.rx(id)
        while succ do
            -- log.info(mcu.x32(id), #data, data:toHex())

            -- 处理数据
            handle_can(id, data)

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

local function upload()
    log.info("upload()", json.encode(devices))
    for k, device in pairs(devices) do
        if device.changed then
            cloud.publish("tillan/upload", device.changes)
            device.changed = false
            device.changes = {}
        end
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

    -- 定时上传
    sys.timerLoopStart(upload, 10000)
end

function tillan.send()

end

return tillan
