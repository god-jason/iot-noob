local tag = "loader"
local loader = {}

function loader.load(name)
    local ret, mod = pcall(require, name)
    log.info(tag, "load", name, ret, mod)
end

function loader.walk(path, base, offset)
    offset = offset or 0
    base = base or ""
    log.info(tag, "walk", path, base, offset)

    local ret, data = io.lsdir(path, 50, offset)
    if not ret then
        return
    end

    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            -- 文件夹
            -- log.info(tag, "walk children", fn)
            loader.walk(fn .. "/", base .. e.name .. ".")
        elseif string.endsWith(e.name, ".luac") then
            -- log.info(tag, "walk found", fn, e.size)
            -- 为入口，重复加载会导致死循环
            if fn ~= "/luadb/main.luac" then
                local name = string.sub(e.name, 1, -6)
                loader.load(base .. name)
            end
        end
    end

    -- 继续遍历
    if #data == 50 then
        loader.walk(path, base, offset + 50)
    end
end

return loader
