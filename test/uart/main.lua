
PROJECT = "test"
VERSION = "1.0.0"

-- 引入sys，方便使用
_G.sys = require("sys")
_G.sysplus = require("sysplus")


--local ret = uart.setup(1, 9600)
log.info("boot")


pm.ioVol(pm.IOVOL_ALL_GPIO, 3300) --提供电压

--uart.setup(1, 9600)
--uart.setup(1, 115200)
--uart.setup(1, 115200, 8, 1, uart.NONE, uart.LSB, 1024, 10, 0, 2000)
--uart.setup(1, 115200, 8, 1, uart.NONE, uart.LSB, 1024, 25) //收发正常，换个GPIO都不行
uart.setup(1, 9600, 8, 1, uart.NONE, uart.LSB, 1024, 25) --收正常，发少最后一个字节
--uart.setup(1, 19200, 8, 1, uart.NONE, uart.LSB, 1024, 25)
--uart.setup(1, 38400, 8, 1, uart.NONE, uart.LSB, 1024, 25) //最后一个字符错误
--uart.setup(1, 57600, 8, 1, uart.NONE, uart.LSB, 1024, 25) -- 收发正常的最小波特率


-- sys.timerLoopStart(function()
--     local ret = uart.write(1, string.fromHex("01030000000AC5CD"))
--     log.info("uart write", ret)
-- end, 1000)


sys.timerLoopStart(function()
    --uart.setup(1, 115200, 8, 1, uart.NONE, uart.LSB, 1024, 10)
    local ret = uart.write(1, "123456")
    log.info("uart write", ret)
    --uart.close(1)

end, 2500)

uart.on(1, 'receive', function(id, len)
    log.info("receive:", id, len, uart.rxSize(1))
    local data = uart.read(id, len)
    log.info("receive data:", #data, data, string.toHex(data))
end)


local id = 1
local en_id = 1
-- sys.taskInit(function()
--     while true do
--         uart.close(id)
--         sys.wait(100)

--         local ret = uart.setup(id, 115200, 8, 1, uart.NONE, uart.LSB, 1024, en_id)
--         log.info("uart open", ret, en_id)
--         sys.wait(100)

--         ret = uart.write(id, "uart gpio "..en_id)
--         log.info("uart write", ret, en_id)
--         --uart.close(1)
    
--         en_id = en_id + 1
--         if en_id > 60 then
--             en_id = 1
--         end

--         sys.wait(100)
--     end
-- end)

sys.run()