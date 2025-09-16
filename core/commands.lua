--- 指令处理
--- @module "commands"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.30
--local tag = "commands"
local commands = {}

local utils = require("utils")
local configs = require("configs")
--local links = require("links")
local devices = require("devices")
local ota = require("ota")

local function response(ret, msg, data)
    return {
        ret = ret,
        msg = msg,
        data = data
    }
end

local function data(d)
    return response(1, nil, d)
end

local function ok(msg)
    return response(1, msg)
end

local function error(err)
    return response(0, err)
end

function commands.error(err)
    return response(0, err)
end

function commands.hello()
    return ok("world")
end

function commands.commands()
    local cmds = {}
    for k, v in pairs(commands) do
        table.insert(cmds, k)
    end
    return data(cmds)
end

function commands.eval(msg)
    local fn = load(msg.data, "eval", "t", _G)
    if fn ~= nil then
        local ret, info = pcall(fn)
        if ret then
            return data(info)
        else
            return error(info)
        end
    else
        return error("load failed")
    end
end

function commands.version()
    return data(_G.PROJECT .. _G.VERSION)
end

function commands.reboot()
    sys.timerStart(rtos.reboot, 5000)
    return ok("reboot after 5s")
end

function commands.ota(msg)
    ota.download(msg.url)
    return ok()
end

function commands.config_read(msg)
    local ret, dat, path = configs.load(msg.name)
    if ret then
        return response(1, path, dat)
    else
        return error("not found")
    end
end

function commands.config_write(msg)
    local ret, path = configs.save(msg.name, msg.data)
    if ret then
        return ok(path)
    else
        return error("write failed")
    end
end

function commands.config_delete(msg)
    configs.delete(msg.name)
    return ok()
end

function commands.config_download(msg)
    configs.download(msg.name, msg.url)
    return ok()
end

function commands.fs_walk(msg)
    local files = {}
    utils.walk(msg.path or "/", files)
    return data(files)
end

function commands.fs_clear()
    utils.remove_all("/")
    -- utils.walk("/")
    return ok("clear_fs finished")
end

function commands.fs_read(msg)
    local dat = io.readFile(msg.path)
    return data(dat)
end

function commands.fs_write(msg)
    local ret = io.writeFile(msg.path, msg.data)
    if ret then
        return ok()
    else
        return error("write failed")
    end
end

function commands.fs_delete(msg)
    os.remove(msg.path)
    return ok()
end

function commands.fs_ls(msg)
    local ret, files = io.lsdir(msg.path or "/", msg.offset, msg.length)
    if ret then
        return data(files)
    else
        return error("lsdir failed")
    end
end

function commands.device_read(msg)
    local dev = devices.get(msg.id)
    if not dev then
        return error("device not found")
    end

    local ret, value = dev.get(msg.name)
    if ret then
        return data(value)
    else
        return error("device read failed")
    end
end

function commands.device_write(msg)
    local dev = devices.get(msg.id)
    if not dev then
        return error("device not found")
    end

    local ret = dev.set(msg.name, msg.value)
    if ret then
        return ok()
    else
        return error("device write failed")
    end
end

function commands.device_action(msg)
    local dev = devices.get(msg.id)
    if not dev then
        return error("device not found")
    end

    -- 执行一系列动作
    for _, item in ipairs(msg.data) do
        sys.timerStart(function()
            dev.set(item.name, item.value)
        end, item.delay or 0)
    end

    return ok()
end

return commands
