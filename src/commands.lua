--- 指令处理
--- @module "commands"
--- @author 杰神
--- @license GPLv3
--- @copyright benyi
--- @release 2025.03.30
local tag = "commands"
local commands = {}


local utils = require("utils")
local configs = require("configs")
local battery = require("battery")
local links = require("links")
local devices = require("devices")
local ota = require("ota")
local gnss = require("gnss")


local function response(ret, msg, data)
    return {
        ret = ret,
        msg = msg,
        data = data
    }
end

local function response_data(data)
    return response(1, nil, data)
end

local function response_ok(msg)
    return response(1, msg)
end

local function response_error(msg)
    return response(0, msg)
end


function commands.error(msg)
    return response(0, msg)
end

function commands.hello()
    return response_ok("world")
end

function commands.commands()
    local cmds = {}
    for k, v in pairs(commands) do
        table.insert(cmds, k)
    end
    return response_data(cmds)
end

function commands.version()
    return response_data(_G.PROJECT .. _G.VERSION)
end

function commands.reboot(msg)
    sys.timerStart(rtos.reboot, 5000)
    return response_ok("reboot after 5s")
end

function commands.ota(msg)
    ota.download(msg.url)
    return response_ok()
end

function commands.config_read(msg)
    local ret, data, path = configs.load(msg.name)
    if ret then
        return response(1, path, data)
    else
        return response_error("not found")
    end
end

function commands.config_write(msg)
    local ret, path = configs.save(msg.name, msg.data)
    if ret then
        return response_ok(path)
    else
        return response_error("write failed")
    end
end

function commands.config_delete(msg)
    configs.delete(msg.name)
    return response_ok()
end

function commands.config_download(msg)
    configs.download(msg.name, msg.url)    
    return response_ok()
end

function commands.fs_walk(msg)
    local files = {}
    utils.walk(msg.data or "/", files)
    return response_data(files)
end

function commands.fs_clear()
    utils.remove_all("/")
    -- utils.walk("/")
    return response_ok("clear_fs finished")
end

function commands.remove(msg)
    os.remove(msg.name)
    return response_ok()
end

function commands.device_read(data)
    local dev = devices.get(data.id)
    if not dev then
        return response_error("device not found")
    end

    local ret, value = dev.get(data.key)
    if ret then
        return response_data(value)
    else
        return response_error("device read failed")
    end
end

function commands.device_write(data)
    local dev = devices.get(data.id)
    if not dev then
        return response_error("device not found")
    end

    local ret = dev.set(data.key, data.value)
    if ret then
        return response_ok()
    else
        return response_error("device write failed")        
    end
end

function commands.device_action(data)
    local dev = devices.get(data.id)
    if not dev then
        return response_error("device not found")
    end

    -- 执行一系列动作
    for _, item in ipairs(data.action) do
        sys.timerStart(function()
            dev.set(item.key, item.value)
        end, item.delay or 0)
    end
    
    return response_ok()
end



return commands
