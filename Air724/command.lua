--- 模块功能：网关命令处理
-- @module command
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30

module(..., package.seeall)

function reply(msg, data)
    local body = data or {}
    body.cmd = msg.cmd -- 回复命令
    body.sn = msg.sn -- 回复序号，方便对应
    return body
end


function reboot(msg)
    local ret = rtos.reboot()
    return reply(msg, {ret = ret})
end

require "fs"

-- 遍历目录
function list(msg)
    local data = fs.list(msg.dir, msg.skip, msg.limit)
    return reply(msg, {ret = 1, data = data})
end

-- 重命名
function rename(msg)
    local ret = fs.rename(msg.path, msg.new)
    return reply(msg, {ret = ret})
end

-- 删除
function remove(msg)
    local ret = fs.remove(msg.path)
    return reply(msg, {ret = ret})
end

-- 删除目录
function removeDir(msg)
    local ret = fs.removeDir(msg.path)
    return reply(msg, {ret = ret})
end

-- 创建目录
function makeDir(msg)
    local ret = fs.makeDir(msg.path)
    return reply(msg, {ret = ret})
end

-- 文件存在
function exists(msg)
    local ret = fs.exists(msg.path)
    return reply(msg, {ret = ret})
end

-- 读取文件
function read(msg)
    local ret = fs.read(msg.path)
    return reply(msg, {ret = ret})
end

-- 读取文件（部分内容）
function readPart(msg)
    local ret = fs.readPart(msg.path, msg.offset, msg.size)
    return reply(msg, {ret = ret})
end

-- 写入文件
function write(msg)
    local ret = fs.write(msg.path, msg.data)
    return reply(msg, {ret = ret})
end

-- 写入文件
function writeAppend(msg)
    local ret = fs.writeAppend(msg.path, msg.data)
    return reply(msg, {ret = ret})
end

-- 写入文件（掉电保护）
function writeSafe(msg)
    local ret = fs.writeSafe(msg.path, msg.data)
    return reply(msg, {ret = ret})
end