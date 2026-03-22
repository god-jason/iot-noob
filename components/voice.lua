--- 组件 语音
-- @module Voice
local Voice = require("utils").class(require("component"))

require("components").register("voice", Voice)

local log = iot.logger("Voice")

--- 构造函数
function Voice:init()
    log.info("voice init", self.name)

    self.name = self.name

    self.pa_pin = self.pa_pin or 21
    self.power_pin = self.power_pin or 20
    self.i2c_id = self.i2c_id or 0
    self.i2s_id = self.i2s_id or 0

    self.voice_vol = self.voice_vol or 60
    self.mic_vol = self.mic_vol or 80

    self.queue_max = self.queue_max or 10
    self.queue = {}
    self.playing = false
    self.disabled = false

    self:open()
end

function Voice:open()
    gpio.setup(self.pa_pin, 1, gpio.PULLUP)
    gpio.setup(self.power_pin, 1, gpio.PULLUP)

    i2c.setup(self.i2c_id, i2c.FAST)
    i2s.setup(self.i2s_id, 0, 16000, 16, i2s.MONO_R, i2s.MODE_LSB, 16)

    audio.config(0, self.pa_pin, 1, 3, 100, self.power_pin, 1, 100)

    audio.setBus(0, audio.BUS_I2S, {
        chip = "es8311",
        i2cid = self.i2c_id,
        i2sid = self.i2s_id
    })

    audio.vol(0, self.voice_vol)
    audio.micVol(0, self.mic_vol)

    audio.on(0, function(id, msg)
        if msg == audio.DONE then
            iot.setTimeout(function()
                self:play_next()
            end, 100)
        end
    end)
end

--- 关闭
function Voice:close()
    log.info("close")

    self:stop()

    gpio.set(self.pa_pin, 0)
    gpio.set(self.power_pin, 0)

    i2s.close(self.i2s_id)
    i2c.close(self.i2c_id)
end

--- 播放下一个
function Voice:play_next()
    if self.disabled then
        return
    end

    if #self.queue == 0 then
        self.playing = false
        self.emit("change", {
            playing = self.playing
        })
        return
    end

    self.playing = true
    self.emit("change", {
        playing = self.playing
    })

    local item = table.remove(self.queue, 1)

    local ret
    if item.type == "tts" then
        ret = audio.tts(0, item.data)
    elseif item.type == "file" then
        ret = audio.play(0, item.data)
    end

    if not ret then
        log.error("play failed", item.type, item.data)
        iot.setTimeout(function()
            self:play_next()
        end, 100)
    end
end

--- 讲话
function Voice:speak(text, high)
    if self.disabled then
        return
    end

    log.info("speak", text)

    local item = {
        type = "tts",
        data = text
    }

    if high then
        table.insert(self.queue, 1, item)
    else
        table.insert(self.queue, item)
    end

    if #self.queue > self.queue_max then
        table.remove(self.queue, 1)
    end

    if not self.playing then
        self:play_next()
    end
end

--- 播放文件
function Voice:play(path, high)
    if self.disabled then
        return
    end

    log.info("play", path)

    local item = {
        type = "file",
        data = path
    }

    if high then
        table.insert(self.queue, 1, item)
    else
        table.insert(self.queue, item)
    end

    if #self.queue > self.queue_max then
        table.remove(self.queue, 1)
    end

    if not self.playing then
        self:play_next()
    end
end

--- 紧急播放
function Voice:emergency(text)
    audio.playStop(0)

    self.queue = {}
    self.playing = false
    self:speak(text, true)
end

--- 停止
function Voice:stop()
    log.info("stop")

    self.queue = {}
    self.playing = false

    self.emit("change", {
        playing = self.playing
    })

    return audio.playStop(0)
end

--- 暂停
function Voice:pause()
    return audio.pause(0, true)
end

--- 恢复
function Voice:resume()
    return audio.pause(0, false)
end

--- 设置（用于网关控制）
function Voice:set(key, value)
    if key == "speak" then
        self:speak(value)
    elseif key == "play" then
        self:play(value)
    elseif key == "stop" then
        self:stop()
    elseif key == "pause" then
        if value then
            self:pause()
        else
            self:resume()
        end
    elseif key == "disabled" then
        self.disabled = value == true
    else
        return false, "Voice未支持的组件参数" .. key
    end
end

function Voice:get(key)
    if key == "playing" then
        return true, self.playing
    else
        return false, "Voice未支持的组件参数" .. key
    end
end

return Voice
