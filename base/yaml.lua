--- YAML 编码/解码库
-- @module yaml
local yaml = {}

-- 判断是否是数组（连续整数键）
local function is_array(t)
    if type(t) ~= "table" then
        return false
    end
    local i = 1
    for k, _ in pairs(t) do
        if k ~= i then
            return false
        end
        i = i + 1
    end
    return true
end

-- 格式化值为 YAML
local function format_value(v)
    local t = type(v)
    if t == "string" then
        -- 多行字符串处理
        if v:find("\n") then
            return "|-\n" .. v:gsub("([^\n]+)", "  %1")
        end
        if v:match("[:%-#{}\\]|[%c]") or v:match("^%s") then
            v = '"' .. v:gsub('"', '\\"') .. '"'
        end
        return v
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        return nil
    else
        return tostring(v)
    end
end

-- 递归编码表
local function encode_table(t, indent)
    indent = indent or 0
    local lines = {}
    local prefix = string.rep("  ", indent)

    if is_array(t) then
        for _, v in ipairs(t) do
            local val = format_value(v)
            if val then
                table.insert(lines, prefix .. "- " .. val)
            else
                table.insert(lines, prefix .. "-")
                local nested = encode_table(v, indent + 1)
                for _, l in ipairs(nested) do
                    table.insert(lines, l)
                end
            end
        end
    else
        for k, v in pairs(t) do
            local key = tostring(k)
            local val = format_value(v)
            if val then
                table.insert(lines, prefix .. key .. ": " .. val)
            elseif type(v) == "table" then
                table.insert(lines, prefix .. key .. ":")
                local nested = encode_table(v, indent + 1)
                for _, l in ipairs(nested) do
                    table.insert(lines, l)
                end
            else
                table.insert(lines, prefix .. key .. ": " .. tostring(v))
            end
        end
    end
    return lines
end

--- 编码
-- @param tbl 表
-- @return 文本
function yaml.encode(tbl)
    -- assert(type(tbl) == "table", "yaml.dump expects a table")
    local lines = encode_table(tbl)
    return table.concat(lines, "\n")
end

-- 内部函数：解析单行值
local function parse_value(val)
    if val == "true" then
        return true
    end
    if val == "false" then
        return false
    end
    if tonumber(val) then
        return tonumber(val)
    end
    if val:match('^".*"$') then
        return val:sub(2, -2):gsub('\\"', '"')
    end
    return val
end

--- 解码
-- @param text 文本
-- @return 表
function yaml.decode(text)
    local result = {}
    local stack = {result}
    local indent_stack = {0}

    for line in text:gmatch("[^\r\n]+") do
        -- 忽略注释和空行
        if not line:match("^%s*#") and not line:match("^%s*$") then
            local indent, content = line:match("^(%s*)(.*)$")
            local level = #indent / 2

            -- 调整栈
            while level < #stack - 1 do
                table.remove(stack)
                table.remove(indent_stack)
            end
            local parent = stack[#stack]

            -- 列表项
            local dash, val = content:match("^%-[ ]*(.*)$")
            if dash then
                local v
                if val == "" then
                    v = {}
                    table.insert(parent, v)
                    table.insert(stack, v)
                    table.insert(indent_stack, level + 1)
                else
                    v = parse_value(val)
                    table.insert(parent, v)
                end
            else
                local key, value = content:match("^(.-):[ ]*(.*)$")
                if key then
                    key = key:gsub("^%s+", ""):gsub("%s+$", "")
                    if value == "" then
                        value = {}
                        parent[key] = value
                        table.insert(stack, value)
                        table.insert(indent_stack, level + 1)
                    else
                        parent[key] = parse_value(value)
                    end
                end
            end
        end
    end
    return result
end

return yaml
