--- 物联小白标准库
-- @author 杰神
-- @license GPLv3
-- @copyright benyi 2025


--- 指令处理
-- @module commands
local commands = {}

--local tag = "commands"

local utils = require("utils")
local configs = require("configs")
local gateway = require("gateway")

local function reply(ret, msg, data)
    return {
        ret = ret,
        msg = msg,
        data = data
    }
end

local function reply_data(d)
    return reply(1, nil, d)
end

local function reply_ok(msg)
    return reply(1, msg)
end

local function reply_error(err)
    return reply(0, err)
end

function commands.error(err)
    return reply(0, err)
end

function commands.hello()
    return reply_ok("world")
end

function commands.commands()
    local cmds = {}
    for k, _ in pairs(commands) do
        table.insert(cmds, k)
    end
    return reply_data(cmds)
end

function commands.eval(msg)
    local fn = load(msg.data, "eval", "t", _G)
    if fn ~= nil then
        local ret, info = pcall(fn)
        if ret then
            return reply_data(info)
        else
            return reply_error(info)
        end
    else
        return reply_error("compile script failed")
    end
end

function commands.version()
    return reply_data(_G.PROJECT .. _G.VERSION)
end

function commands.reboot()
    sys.timerStart(rtos.reboot, 5000)
    return reply_ok("reboot after 5s")
end

function commands.config_read(msg)
    local ret, dat, path = configs.load(msg.name)
    if ret then
        return reply(1, path, dat)
    else
        return reply_error("not found")
    end
end

function commands.config_write(msg)
    local ret, path = configs.save(msg.name, msg.data)
    if ret then
        return reply_ok(path)
    else
        return reply_error("write failed")
    end
end

function commands.config_delete(msg)
    configs.delete(msg.name)
    return reply_ok()
end

function commands.config_download(msg)
    configs.download(msg.name, msg.url)
    return reply_ok()
end

function commands.fs_walk(msg)
    local files = {}
    utils.walk(msg.path or "/", files)
    return reply_data(files)
end

function commands.fs_clear()
    utils.remove_all("/")
    -- utils.walk("/")
    return reply_ok("clear_fs finished")
end

function commands.fs_read(msg)
    local dat = io.readFile(msg.path)
    return reply_data(dat)
end

function commands.fs_write(msg)
    local ret = io.writeFile(msg.path, msg.data)
    if ret then
        return reply_ok()
    else
        return reply_error("write failed")
    end
end

function commands.fs_delete(msg)
    os.remove(msg.path)
    return reply_ok()
end

function commands.fs_ls(msg)
    local ret, files = io.lsdir(msg.path or "/", msg.offset, msg.length)
    if ret then
        return reply_data(files)
    else
        return reply_error("lsdir failed")
    end
end

function commands.device_read(msg)
    local dev = gateway.get_device_instanse(msg.id)
    if not dev then
        return reply_error("device not found")
    end

    local ret, value = dev.get(msg.name)
    if ret then
        return reply_data(value)
    else
        return reply_error("device read failed")
    end
end

function commands.device_write(msg)
    local dev = gateway.get_device_instanse(msg.id)
    if not dev then
        return reply_error("device not found")
    end

    local ret = dev.set(msg.name, msg.value)
    if ret then
        return reply_ok()
    else
        return reply_error("device write failed")
    end
end

function commands.device_action(msg)
    local dev = gateway.get_device_instanse(msg.id)
    if not dev then
        return reply_error("device not found")
    end

    -- 执行一系列动作
    for _, item in ipairs(msg.data) do
        sys.timerStart(function()
            dev.set(item.name, item.value)
        end, item.delay or 0)
    end

    return reply_ok()
end

return commands
