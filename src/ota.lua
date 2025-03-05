local tag = "OTA"

function ota_open()
    local ret = fota.init()
end

function ota_write(buf, offset, length)
    local ret, last, remain = fota.run(buf, offset, length)
    return ret
end

function ota_file(path)
    local ret, last, remain = fota.file(path)
    return
end

function ota_done()
    local ret, done = fota.isDone()
    return ret and done
end

function ota_finish()
    local ret = fota.finish(true)
    return ret
end

