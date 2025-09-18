--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 程序加载器，只需要在main.lua中引入，即可将/luadb/之下的所有代码加载
-- @module autoload
local autoload = {}

local tag = "autoload"

--- 加载文件
-- @param name string  模块名
function autoload.load(name)
    -- 使用pcall 避免异常退出
    local ret, info = pcall(require, name)
    if not ret then
        log.error(tag, name, info)
    end
end

--- 遍历目录
-- @param path string 根目录
-- @param base string 无用
-- @param offset integer 无用
function autoload.walk(path, base, offset)
    offset = offset or 0
    base = base or ""
    -- log.info(tag, "walk", path, base, offset)

    local ret, data = io.lsdir(path, 50, offset)
    if not ret then
        return
    end

    for _, e in ipairs(data) do
        local fn = path .. e.name
        if e.type == 1 then
            -- 文件夹
            -- log.info(tag, "walk children", fn)
            autoload.walk(fn .. "/", base .. e.name .. ".")
        elseif string.endsWith(e.name, ".luac") then
            -- log.info(tag, "walk found", fn, e.size)
            -- 为入口，重复加载会导致死循环
            if fn ~= "/luadb/main.luac" then
                local name = string.sub(e.name, 1, -6)
                autoload.load(base .. name)
            end

            -- 降低启动速度，避免日志输出太快，从而导致丢失
            if log.getLevel() < 2 then
                sys.wait(100)
            end
        end
    end

    -- 继续遍历
    if #data == 50 then
        autoload.walk(path, base, offset + 50)
    end
end

--遍历所有编译的工程文件，然后require，实现自动加载
autoload.walk("/luadb/")

return autoload
