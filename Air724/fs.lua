module(..., package.seeall)

local function fileType(tp)
    if tp == 16 then
        return "folder"
    else
        return "file"
    end
end

-- 遍历目录
function list(dir, skip, limit)
    local files = {}
    if io.opendir(dir) then

        local i = 0
        if not skip == nil then
            while i < skip do
                i = i + 1
                io.readdir() -- 忽略之前的
            end
            i = 0
        end

        -- 默认取20个文件
        if limit == nil then limit = 20 end
        while i < limit do
            i = i + 1
            local type, name, size = io.readdir()
            if type == nil then
                break
            else
                table.insert({type = fileType(type), name = name, size = size})
            end
        end
        io.closedir(dir)
    end

    return files
end

-- 重命名
rename = os.rename

-- 删除
remove = os.remove

-- 删除目录
removeDir = rtos.remove_dir

-- 创建目录
makeDir = rtos.make_dir

-- 文件存在
exists = io.exists

-- 读取文件
read = io.readFile

-- 读取文件（部分内容）
readPart = io.readStream

-- 写入文件
function write(path, content) return io.writeFile(path, content, "w+b") end

-- 写入文件
function writeAppend(path, content) return io.writeFile(path, content, "a+b") end

-- 写入文件（掉电保护）
writeSafe = io.write_sfile

