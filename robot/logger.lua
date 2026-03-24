--- 日志上传库
-- @module logger
local logger = {}

local boot = require("boot")
local settings = require("settings")

local logs = {}
local running = false

local function upload_task()
    while running do

        -- TODO 添加熔断机制，避免短时间，大量日志把流量消耗完

        if #logs > 0 then
            local data = table.remove(logs, 1)
            -- 使用HTTP上传
            iot.request(settings.logger.url, {
                method = "POST",
                headers = {
                    ["Content-Type"] = "application/json"
                },
                body = iot.json_encode(data)
            })
        else
            iot.sleep(1000)
        end
    end
end

--- 创建日志
-- @param content 内容
-- @param level 等级 1 2 3，越小等级越高
function logger.log(content, level)
    level = level or 3
    if level <= settings.logger.level and #logs < 10 then
        table.insert(logs, {
            id = settings.logger.id,
            content = content,
            level = level,
            timestamp = os.time()
        })
    end
end

--- 加载
function logger.open()

    -- 默认ID
    settings.logger.id = settings.logger.id or mobile.imei()

    -- 单独线程处理上传任务
    running = true
    iot.start(upload_task)

    -- 监听日志和错误 TODO 需要淘汰
    iot.on("log", function(content, level)
        logger.log(content, level or 3)
    end)
    iot.on("error", function(err, level)
        logger.log("[系统错误] " .. err, level or 1)
    end)

    return true
end

--- 关闭
function logger.close()
    running = false
end


settings.register("logger", {
    url = "https://iot.busycloud.cn/api/log",
    level = 3
})

boot.register("logger", logger, "settings")

return logger
