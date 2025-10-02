-- 适配合宙的LuatOS，主要封装以下模块：
-- 1、文件系统
-- 2、
_G.sys = require("sys") -- 其实已经内置了

local iot = {}

function iot.setTimeout(func, timeout, ...)
    return sys.timerStart(func, timeout, ...)
end

function iot.setInterval(func, timeout, ...)
    return sys.timerloopStart(func, timeout, ...)
end

function iot.clearTimeout(id)
    return sys.timerStop(id)
end

function iot.clearInterval(id)
    return sys.timerStop(id)
end

function iot.start(func, ...)
    -- TODO 这里返回是协程对象，不是线程ID
    return sys.taskInit(func, ...)
end

function iot.stop(id)
    return false
end

function iot.sleep(timeout)
    sys.wait(timeout)
end

function iot.wait(topic, timeout)
    return sys.waitUntil(topic, timeout)
end

function iot.on(topic, func)
    sys.subscribe(topic, func)
end

function iot.once(topic, func)
    local fn = function()
        func()
        sys.unsubscribe(topic, fn)
    end
    sys.subscribe(topic, fn)
end

function iot.off(topic, func)
    sys.unsubscribe(topic, func)
end

function iot.emit(topic, ...)
    sys.publish(topic, ...)
end

function iot.open(filename, mode)
    local fd = io.open(filename, mode)
    return fd ~= nil, fd
end

function iot.exists(filename)
    return io.exists(filename)
end

function iot.readFile(filename)
    local data = io.readFile(filename)
    return data ~= nil, data
end

function iot.writeFile(filename, data)
    return io.writeFile(filename, data)
end

function iot.appendFile(filename, data)
    return io.writeFile(filename, data, "ab+")
end

function iot.md5(data)
    return crypt.md5(data)
end
function iot.hmac_md5(data, key)
    return crypt.hmac_md5(data, key)
end
function iot.sha1(data)
    return crypt.sha1(data)
end
function iot.hmac_sha1(data, key)
    return crypt.hmac_sha1(data, key)
end
function iot.sha256(data)
    return crypt.sha256(data)
end
function iot.hmac_sha256(data, key)
    return crypt.hmac_sha256(data, key)
end
function iot.sha512(data)
    return crypt.sha512(data)
end
function iot.hmac_sha512(data, key)
    return crypt.hmac_sha512(data, key)
end
function iot.encrypt(type, padding, str, key, iv)
    return crypt.encrypt(type, padding, str, key, iv)
end
function iot.decrypt(type, padding, str, key, iv)
    return crypto.decrypt(type, padding, str, key, iv)
end
function iot.base64_encode(data)
    return crypto.base64_encode(data)
end
function iot.base64_decode(data)
    return crypto.base64_decode(data)
end
function iot.crc8(data)
    return crypto.crc8(data)
end
function iot.crc16(method, data)
    return crypto.crc16(method, data)
end
function iot.crc32(data)
    return crypto.crc32(data)
end

return iot
