--- 程序加载器，只需要在main.lua中引入，即可将/luadb/之下的所有代码加载。在luatools工具中，需要勾选“忽略脚本依赖性”，否则只下载main gateway.lua等几个文件，导致启动失败
-- @module autoload
local autoload = {}

local tag = "autoload"

--- 加载文件
-- @param name string  模块名
function autoload.load(name)
    log.info(tag, "load", name)

    -- 使用pcall 避免异常退出
    local ret, info = pcall(require, name)
    if not ret then
        log.error(tag, name, info)
    end

    -- iot.sleep(500) -- 等待一段时间，避免日志输出太快，从而导致丢失
end

function autoload.walk(path)
    iot.walk(path, function(filename)
        if string.endsWith(filename, ".luac") then
            -- log.info(tag, "walk found", fn, e.size)
            -- main为入口，重复加载会导致死循环
            if filename ~= "/luadb/main.luac" then
                local name = string.sub(filename, #path + 1, -6)
                autoload.load(name)
            end
        end
    end)
end

-- 遍历所有编译的工程文件，然后require，实现自动加载
-- autoload.walk("/luadb/") ERROR 此处会导致死循环，耗尽内存

return autoload
