--- 语音封装
-- @module voice
local voice = {}

local log = iot.logger("voice")

local pa_pin, power_pin
local i2c_id, i2s_id

local queue_max = 10
local queue = {}
local playing = false

local function play_next()
    if #queue == 0 then
        playing = false
        return
    end
    playing = true

    local ret
    local item = table.remove(queue, 1)
    if item.type == "tts" then
        ret = audio.tts(0, item.data)
    elseif item.type == "file" then
        ret = audio.play(0, item.data)
    else
        -- 未知类型，不会出现
    end

    if not ret then
        -- play_next()
        log.error("play failed", item.type, item.data)
        iot.setTimeout(play_next, 100)
    end
end

--- 打开
function voice.open(opts)
    log.info("open")
    opts = opts or {}

    -- 默认参数
    pa_pin = opts.pa_pin or 21 -- 喇叭pa功放脚
    power_pin = opts.power_pin or 20 -- es8311电源脚
    i2c_id = opts.i2c_id or 0 -- i2c_id 0
    i2s_id = opts.i2s_id or 0 -- i2s_id 0

    local voice_vol = opts.voice_vol or 60 -- 喇叭音量
    local mic_vol = opts.mic_vol or 80 -- 麦克风音量

    gpio.setup(pa_pin, 1, gpio.PULLUP) -- 设置功放PA脚
    gpio.setup(power_pin, 1, gpio.PULLUP) -- 设置ES83111电源脚

    i2c.setup(i2c_id, i2c.FAST)
    i2s.setup(i2s_id, 0, 16000, 16, i2s.MONO_R, i2s.MODE_LSB, 16)

    audio.config(0, pa_pin, 1, 3, 100, power_pin, 1, 100)
    audio.setBus(0, audio.BUS_I2S, {
        chip = "es8311",
        i2cid = i2c_id,
        i2sid = i2s_id
    }) -- 通道0的硬件输出通道设置为I2S

    audio.vol(0, voice_vol)
    audio.micVol(0, mic_vol)

    -- audio.tts(0, "初始化完成")
    audio.on(0, function(id, msg)
        if msg == audio.DONE then
            -- play_next()
            iot.setTimeout(play_next, 100)
        end
    end)
end

--- 讲话
-- @param text 文本
-- @param high 高优先级
function voice.speak(text, high)
    log.info("speak", text)

    if high then
        table.insert(queue, 1, {
            type = "tts",
            data = text
        })
    else
        table.insert(queue, {
            type = "tts",
            data = text
        })
    end

    -- 去除前面的
    if #queue > queue_max then
        table.remove(queue, 1)
    end

    if not playing then
        play_next()
    end
end

--- 紧急讲话
-- @param text 文本
function voice.emergency(text)
    audio.playStop(0)
    queue = {}
    playing = false
    voice.speak(text)
end

-- 播放音频
-- @param path 文件
-- @param high 高优先级
function voice.play(path, high)
    log.info("play", path)

    if high then
        table.insert(queue, 1, {
            type = "file",
            data = path
        })
    else
        table.insert(queue, {
            type = "file",
            data = path
        })
    end

    -- 去除前面的
    if #queue > queue_max then
        table.remove(queue, 1)
    end

    if not playing then
        play_next()
    end
end

--- 停止
function voice.stop()
    log.info("stop")
    queue = {}
    playing = false
    return audio.playStop(0)
end

--- 暂停
function voice.pause()
    log.info("pause")
    return audio.pause(0, true)
end

--- 恢复
function voice.resume()
    log.info("resume")
    return audio.pause(0, false)
end

--- 结束
function voice.is_end()
    return audio.isEnd(0)
end

--- 关闭
function voice.close()
    log.info("close")

    audio.stop(0)
    queue = {}
    playing = false

    if pa_pin then
        gpio.set(pa_pin, 0)
    end
    if power_pin then
        gpio.set(power_pin, 0)
    end
    if i2s_id then
        i2s.close(i2s_id)
    end
    if i2c_id then
        i2c.close(i2c_id)
    end
end

return voice
