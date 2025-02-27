--- 模块功能：驱动ch395芯片
-- @module cloud
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.07.14
module(..., package.seeall)

local sockets = {nil, nil, nil, nil, nil, nil, nil, nil}

function setup() end

function connect(type, ip, port)

    local id = 0 -- 获取可用ID

    if type == 1 then
        -- TCP
        spi.send_recv(spi.SPI_1, string.char(0x34, 0, 3))

    elseif type == 2 then
        -- UDP
        spi.send_recv(spi.SPI_1, string.char(0x34, 0, 2))

    else
        -- TODO 返回错误
    end

    -- 设置目的地址
    spi.send_recv(spi.SPI_1, string.char(0x31, id) .. ip2bytes(ip))
    -- 设置目的端口号
    spi.send_recv(spi.SPI_1, string.char(0x32, id) .. pack.pack('<H', port))
    -- 设置本地端口
    spi.send_recv(spi.SPI_1, string.char(0x33, id) .. pack.pack('<H', 0)) -- TODO 生成本地端口
    -- 打开socket
    spi.send_recv(spi.SPI_1, string.char(0x35, id))

    --等待结果
    local state = inquire2c(30)
    if state ~= '\x00' or type == UDPCLIENT then
        if type ~= UDPCLIENT then
            log.info('socketCh395', 'open socket err', state:toHex())
        else
            sys.timerStart(function()
                sys.publish('SOCK_CONN_CNF', {
                    ['socket_index'] = socketId,
                    ['id'] = 34,
                    ['result'] = 0
                })
            end, 200)

        end

        return state
    end
    spi.send_recv(spi.SPI_1, string.char(0x37, id))

    state = inquire2c()
    if state == '\x00' then
        sys.publish('SOCK_CONN_CNF',
                    {['socket_index'] = id, ['id'] = 34, ['result'] = 0})
    else
        
    end

    return state

end

local function ip2bytes(ip)
    local d1, d2, d3, d4 = string.match(ip, '(%d+)%.(%d+)%.(%d+).(%d+)')
    return pack.pack('b4', d1, d2, d3, d4)
end

-- 命令执行查询
local function inquire2c(time)
    local num = 0
    while true do
        sys.wait(time or 10)
        local data = string.sub(spi.send_recv(spi.SPI_1, '\x2c\xff'), 2, 2)
        if data ~= '\x10' then return data end
        num = num + 1
        if num > 100 then return data end
    end
end

function close(id)
    -- spi.send_recv(spi.SPI_1, string.char(0x38, id)) --关闭server连接
    spi.send_recv(spi.SPI_1, string.char(0x3D, id))
    local state = inquire2c(10)
    
end



-- 配置8路socket收发缓存
local function socketBufferConfig()
    -- 只有硬件版本大于47才有4-7路
    local b = 0
    for i = 0, 7 do
        spiSend(spi.SPI_1, string.char(0x52, i, b, 4))
        b = b + 4
        spiSend(spi.SPI_1, string.char(0x53, i, b, 2))
        b = b + 2
        sys.wait(500)
    end
end


local function str2short(str)
    local f, n = pack.unpack(str, '<H')
    return f and f > 0 and n or 0
end

-- 处理中断
local function interruptProcess()
    local intAll = string.sub(spi.send_recv(spi.SPI_1, '\x19\xff\xff'), 2, -1)
    -- log.info('INT30', intAll:toHex())
    intAll = str2short(intAll)
    if intAll == 0 or intAll == 65535 then return end
    -- 处理PHY中断
    if bit.isset(intAll, 2) then
        local statePhy = string.sub(spi.send_recv(spi.SPI_1, '\x26\xff'), 2, -1)
        if statePhy == '\x01' then
            log.info('socketCh395', 'phy false')
            ipError()
        elseif statePhy == '\x08' then
            log.info('socketCh395', 'phy true')

        end
    end
    -- 处理DHCP中断
    if bit.isset(intAll, 3) then
        -- DHCP中断
        local stateDhcp = string.sub(spi.send_recv(spi.SPI_1, '\x42\xff'), 2, -1)
        if stateDhcp == '\x00' then
            log.info('socketCh395', 'DHCP true')
        elseif stateDhcp == '\x01' then
            log.info('socketCh395', 'DHCP false')
            ipError()
        end
    end
    -- 处理不可达中断
    if bit.isset(intAll, 0) then
        -- 读取不可达信息？
        log.info('socketCh395', 'Unreachable interrupt')
        -- getUnreachIpport()
    end
    -- 处理IP冲突中断
    if bit.isset(intAll, 1) then
        log.info("IP", 'IP conflict')
        -- 建议重新修改本地IP，并初始化芯片（未加）
    end

    -- socket0-7中断
    local socketIntId = {}
    for i = 4, 11 do
        if bit.isset(intAll, i) then table.insert(socketIntId, (i - 4)) end
    end
    local socketCloss = {}
    -- 逐个socket查询中断并处理
    for q = 1, #socketIntId do
        local socketState = string.sub(spi.send_recv(spi.SPI_1, string.char(0x30,
                                                                      socketIntId[q],
                                                                      0xff, 0xff)),
                                       3, -1)
        -- log.info('INT19:' .. socketIntId[q], socketState:toHex())
        socketState = str2short(socketState)
        -- TCP连接
        if bit.isset(socketState, 3) then
            -- sockets[socketIntId[q]].connected = true
            if sockets[socketIntId[q]] == true then
                local data = string.sub(spiSend(spi.SPI_1, string.char(0x2d,
                                                                       socketIntId[q],
                                                                       0xff,
                                                                       0xff,
                                                                       0xff,
                                                                       0xff,
                                                                       0xff,
                                                                       0xff)),
                                        3, 8)
                -- server
                local socketData = {
                    id = socketIntId[q],
                    ip = ip2num(string.sub(data, 1, 4)),
                    port = str2short(string.sub(data, 5, 6))

                }
                sys.publish('tcpServer', socketData)
            else
                sys.publish('SOCK_CONN_CNF', {
                    ['socket_index'] = socketIntId[q],
                    ['id'] = 34,
                    ['result'] = 0
                })
            end

        end
        -- 接收缓冲区非空
        if bit.isset(socketState, 2) then
            local data_leng
            local data
            data_leng = string.sub(spiSend(spi.SPI_1, string.char(0x3b,
                                                                  socketIntId[q],
                                                                  0xff, 0xff)),
                                   3, -1)
            -- if data_leng == '\x00\x00' then
            --     break
            -- end
            data = string.sub(spiSend(spi.SPI_1,
                                      string.char(0x3c, socketIntId[q]) ..
                                          data_leng ..
                                          string.rep('\xff',
                                                     str2short(data_leng))), 5,
                              -1)
            sys.timerStart(function()
                sys.publish('MSG_SOCK_RECV_IND', {
                    ['socket_index'] = socketIntId[q],
                    ['id'] = 31,
                    ['result'] = 0,
                    ['recv_len'] = str2short(data_leng),
                    ['recv_data'] = data
                })
            end, 10)

            -- data_leng = string.sub(spiSend(spi.SPI_1, string.char(0x3b, socketIntId[q], 0xff, 0xff)), 3, -1)
            -- data = string.sub(spiSend(spi.SPI_1, string.char(0x3c, socketIntId[q]) .. data_leng ..
            --     string.rep('\xff', str2short(data_leng))), 5, -1)
            -- sys.publish('MSG_SOCK_RECV_IND', {
            --     ['socket_index'] = socketIntId[q],
            --     ['id'] = 31,
            --     ['result'] = 0,
            --     ['recv_len'] = str2short(data_leng),
            --     ['recv_data'] = data
            -- })
        end
        -- 发送缓冲区空闲
        if bit.isset(socketState, 0) then
            if sockets[socketIntId[q]] and sockets[socketIntId[q]] ~= true then
                sockets[socketIntId[q]].sendstate = true
            else
                log.info('socketCh395', 'sendstate err:' .. socketIntId[q])
            end
        end
        -- 发送成功
        if bit.isset(socketState, 1) then

            sys.publish('SOCK_SEND_CNF', {
                ['socket_index'] = socketIntId[q],
                ['id'] = 32,
                ['result'] = 0
            })

        end

        -- TCP断开
        if bit.isset(socketState, 4) then
            table.insert(socketCloss, {
                ['socket_index'] = socketIntId[q],
                ['id'] = 33,
                ['result'] = 0
            })

        end
        -- 超时
        if bit.isset(socketState, 6) then
            -- 超时处理，重新开启重新连接（未加）
            -- 打开socket
            log.info('socketCh395', 'socket conn timeout' .. socketIntId[q],
                     sockets[socketIntId[q]], socketIntId[q])
            -- if not sockets[socketIntId[q]] then
            --     sockectCh395Close(socketIntId[q])
            -- elseif sockets[socketIntId[q]] ~= 0 then

            --     local ty = sockets[socketIntId[q]].protocol
            --     local soalAddress = sockets[socketIntId[q]].address
            --     local soalPort = sockets[socketIntId[q]].port
            --     local localPort = sockets[socketIntId[q]].localPort
            --     sockectCh395Close(socketIntId[q])
            --     if ty == 'TCP' then
            --         ty = TCPCLIENT
            --     elseif ty == 'UDP' then
            --         ty = UDPCLIENT
            --     end
            --     SocketClientInit(ty, socketIntId[q], soalAddress, soalPort, localPort)
            -- end

        end
    end
    for i = 0, 7 do
        if sockets[i] then
            local data_leng
            local data
            data_leng = string.sub(spiSend(spi.SPI_1,
                                           string.char(0x3b, i, 0xff, 0xff)), 3,
                                   -1)
            if data_leng ~= "\x00\x00" then
                data = string.sub(spiSend(spi.SPI_1, string.char(0x3c, i) ..
                                              data_leng ..
                                              string.rep('\xff',
                                                         str2short(data_leng))),
                                  5, -1)
                sys.timerStart(function()
                    sys.publish('MSG_SOCK_RECV_IND', {
                        ['socket_index'] = i,
                        ['id'] = 31,
                        ['result'] = 0,
                        ['recv_len'] = str2short(data_leng),
                        ['recv_data'] = data
                    })
                end, 10)

            end

        end
    end
    for w = 1, #socketCloss do
        local data = string.sub(spiSend(spi.SPI_1, string.char(0x2F,
                                                               socketCloss[w]['socket_index'],
                                                               0xff, 0xff)), 3,
                                -1)
        local data1 = string.sub(data, 1, 1)
        local data2 = string.sub(data, 2, 2)
        -- if data1 == '\x00' then
        if not sockets[socketCloss[w]['socket_index']] or
            sockets[socketCloss[w]['socket_index']] == true then
            sys.timerStart(function(...)
                log.info('socketCh395', 'socket ' ..
                             socketCloss[w]['socket_index'] .. 'state' ..
                             data:toHex())
                sys.publish('MSG_SOCK_CLOSE_IND', socketCloss[w])
                log.info('socketCh395', 'Disconnection socket ',
                         socketCloss[w]['socket_index'])
            end, 200)

        elseif sockets[socketCloss[w]['socket_index']].protocol ==
            'TCPSERVERCLIENT' then
            -- sockets[socketCloss[w]['socket_index']]=true
            sys.timerStart(function(...)
                log.info('socketCh395', 'socket ' ..
                             socketCloss[w]['socket_index'] .. 'state' ..
                             data:toHex())
                sys.publish('MSG_SOCK_CLOSE_IND', socketCloss[w])
                log.info('socketCh395', 'Disconnection socket ',
                         socketCloss[w]['socket_index'])
            end, 200)
        else
            sys.timerStart(function(...)
                log.info('socketCh395', 'socket ' ..
                             socketCloss[w]['socket_index'] .. 'state' ..
                             data:toHex())
                sys.publish('MSG_SOCK_CLOSE_IND', socketCloss[w])
                log.info('socketCh395', 'Disconnection socket ',
                         socketCloss[w]['socket_index'])
            end, 200)
        end

        -- end

    end
    sys.wait(10)
end

local number = 0
sys.taskInit(function()
    while true do
        if number > 0 or sys.waitUntil("interruptProcess") then
            interruptProcess()
            number = number - 1
            -- sys.wait(5)
        end
    end
end)

-- 配置中断检测
local function setInt(state)
    if state then
        pio.pin.setdebounce(5)
        pins.setup(configurationCh395['intPin'], function(a)
            if a == 2 then
                number = number + 2
                sys.publish("interruptProcess")
            else

            end
        end)
        pio.pin.setdebounce(20)
    else
        pins.close(configurationCh395['intPin'])
    end
end

--- 初始化CG395模块
-- @table para，取值如下：
--               para为table类型，表示以太网的配置参数，参数结构如下：
--                 {
--                     mode = 1,      --1表示客户端；2表示服务器；默认为1
--                     intPin = pio.P0_22,      --以太网芯片中断通知引脚
--                     rstPin = pio.P0_23,      --复位以太网芯片引脚
--                     clientNum = 6, -- server可连路数
--                     spiCs = pio.P0_23,      --SPI片选
--                     CH395MAC = "84C2E4A82950",      --MAC地址
--                     localAddr = "192.168.1.112",      --本机的地址
--                     localPort = 1888,      --server本机的端口
--                     spiCs=pio.P0_7,  --spi片选
--                     localGateway = "192.168.1.1",      --本机的网关地址
--                     func=function(id, msg, dat)end,     --中断处理函数，处理server中断事件
--                     powerFunc=function(state) end           --控制以太网模块的供电开关函数，ret为true开启供电，false关闭供电
--                     spi = {spi.SPI_1,0,0,8,800000},      --SPI通道参数，id,cpha,cpol,dataBits,clock，默认spi.SPI_1,0,0,8,800000
--                 }
-- @return result 数据接收结果
--                true表示成功
--                false表示失败
-- @usage
-- socketCh395.open(para)
function open(para)
    configurationCh395 = para
    powerCbFnc = nil or para['powerFunc']
    -- 供电及其他前置条件
    if powerCbFnc then powerCbFnc(true) end
    -- 复位芯片
    spiSend(spi.SPI_1, '\x05')
    -- 开启SPI
    if not spi.setup(para['spi'][1], para['spi'][2], para['spi'][3],
                     para['spi'][4], para['spi'][5], 1) == 1 then
        log.info('socketCh395', 'open spi err')
        return ''
    end
    -- 设置中断
    setInt(true)
    -- 芯片进入SPI模式
    local setGpioFnc_RSTI = pins.setup(para['rstPin'], 0)
    setGpioFnc_RSTI(0)
    sys.wait(100)
    setGpioFnc_RSTI(1)
    sys.wait(200)
    -- 测试是否成功建立通讯
    local state06 = string.sub(spiSend(spi.SPI_1, '\x06\x55\xff'), 3, 3)
    state06 = state06 == '\xaa'
    log.info('CH395 state', state06)
    if not state06 then
        log.info('socketCh395', 'err cannot work')
        return ''
    end
    -- server多连接设置
    if para['mode'] == 2 then
        spiSend(spi.SPI_1, '\x55\x02')
        local stateInit = inquire2c(50)
        if stateInit ~= '\x00' then
            log.info('open server')
        else
            log.info('open server err', stateInit:toHex())
        end
    end

    -- 获取芯片版本
    ch395Version = string.sub(spiSend(spi.SPI_1, '\x01\xff'), 2, 2)

    -- 配置芯片信息
    if para['localAddr'] and para['localGateway'] then
        -- 配置本地信息
        local gateway = iptostr(para['localGateway'])
        local addr = iptostr(para['localAddr'])

        spiSend(spi.SPI_1, '\x22' .. addr[1] .. addr[2] .. addr[3] .. addr[4])
        spiSend(spi.SPI_1,
                '\x23' .. gateway[1] .. gateway[2] .. gateway[3] .. gateway[4])
        if para['localSubnetMas'] then
            local subnetMas = iptostr(para['localSubnetMas'])
            spiSend(spi.SPI_1, '\x24' .. subnetMas[1] .. subnetMas[2] ..
                        subnetMas[3] .. subnetMas[4])
        end
    end
    -- 设置收发缓存（默认8路）
    socketBufferConfig()
    -- 模块初始化
    spiSend(spi.SPI_1, '\x27')
    local stateInit = inquire2c(50)
    if stateInit ~= '\x00' then
        log.info('socketCh395', 'ch395 INIT err' .. stateInit:toHex())
        return ''
    end
    -- 设置MAC地址
    if para['CH395MAC'] and string.len(para['CH395MAC']) == 12 then
        spiSend(spi.SPI_1, '\x21' .. string.fromHex(para['CH395MAC']))
        sys.wait(200)
    end

    -- 获取芯片MAC
    CH395MAC = string.sub(spiSend(spi.SPI_1,
                                  string.fromHex('40FFFFFFFFFFFF2cff')), 2, 7)
    if CH395MAC == string.char(0, 0, 0, 0, 0, 0) then CH395MAC = nil end

    -- DHCP
    if not (para['localAddr'] and para['localGateway']) then
        spiSend(spi.SPI_1, '\x41\x01')
        local stateDhcp = inquire2c(30)
        if stateDhcp ~= '\x00' then
            log.info('socketCh395', 'ch395 INIT err' .. stateDhcp:toHex())
            return ''
        end
    end
    -- 获取本地IP
    for q = 1, 20 do
        sys.wait(500)
        local dataIp = string.sub(spiSend(spi.SPI_1, string.fromHex(
                                              '43ffffffffffffffffffffffffffffffffffffffff')),
                                  2, -1)
        if link.getNetwork() == link.CH395 and string.sub(dataIp, 1, 4) ~=
            '\xff\xff\xff\xff' and string.sub(dataIp, 1, 4) ~=
            '\x00\x00\x00\x00' then
            local ch395Ip = ip2num(string.sub(dataIp, 1, 4))
            log.info('ip', ch395Ip)
            link.setReady(link.CH395, true)
            sys.publish('IP_READY_IND')
            return ch395Ip
        end
    end
    return ''
end

---  开关模块
function close()
    link.setReady(link.CH395, false)
    sys.publish('IP_ERROR_IND')
    -- 关闭所有socket
    for i = 0, 7 do
        spiSend(spi.SPI_1, string.char(0x3D, i))
        sockets[i] = nil
    end
    -- 关闭中断检测
    setInt(false)
    -- 关闭SPI
    if not spi.close(configurationCh395['spi'][1]) == 1 then
        log.info('socketCh395 close spi err', configurationCh395['spi'][1],
                 configurationCh395['spi'][2], configurationCh395['spi'][3],
                 configurationCh395['spi'][4], configurationCh395['spi'][5], 1)
        return false
    end

    -- 关闭模块
    if powerCbFnc then powerCbFnc(false) end
    return true
end

---建立套接字连接
local function sockectCh395Conn(type, addr, port, lcoalPort, data)
    local socketId = nil

    for i = 0, 7 do
        if not sockets[i] then
            socketId = i
            data.id = i
            sockets[i] = data
            break
        end
        if i == 7 then
            log.info('socketCh395', 'No socket available ')
            return nil
        end
    end
    if type == TCPCLIENT or type == UDPCLIENT then
        local tcpClientState = SocketClientInit(type, socketId, addr, port,
                                                lcoalPort)
        if tcpClientState == '\x00' then
            return socketId
        else
            spiSend(spi.SPI_1, string.char(0x3D, socketId))
            local stateClose = inquire2c(50)
            if stateClose == '\x00' then
                log.info('sockectCh395', 'close socket' .. socketId .. 'true')
            end
            sockets[socketId] = nil
            return nil
        end
    elseif type == TCPSERVER then

    end
end

-- 发送数据
local function sockectCh395Send(socketId, data)
    for i = 1, 10 do
        if sockets[socketId] and sockets[socketId] ~= true and
            sockets[socketId].sendstate then
            spiSend(spi.SPI_1,
                    '\x39' .. string.char(socketId) .. shorts(#data) .. data)
            local state = inquire2c(50)
            if state == '\x00' then
                sys.publish('SOCK_SEND_CNF', {
                    ['socket_index'] = socketId,
                    ['id'] = 32,
                    ['result'] = 0
                })
            else
                sys.publish('SOCK_SEND_CNF', {
                    ['socket_index'] = socketId,
                    ['id'] = 32,
                    ['result'] = 1
                })
            end
            log.info('socketCh395', socketId .. 'send state' .. state:toHex())
            break
        elseif not sockets[socketId] or sockets[socketId] == true then
            -- log.info('socketCh395', 'send err, not socket ' .. socketId)
        else
            sys.wait(100)
        end
    end
end

-- 接收数据
local function sockectCh395Recv(socketId, buffLen)
    local data_leng = string.sub(spiSend(spi.SPI_1, string.char(0x3b, socketId,
                                                                0xff, 0xff)), 3,
                                 -1)
    local data = string.sub(spiSend(spi.SPI_1,
                                    string.char(0x3c, socketId) .. data_leng ..
                                        string.rep('\xff', str2short(data_leng))),
                            5, -1)
    return data
end
-- table 深拷贝
local function clone(tb)
    local ret = {}
    for k, v in pairs(tb) do ret[k] = type(v) == "table" and clone(v) or v end
    return ret
end
-- 创建server
local function initServer(port, num, data)
    if num > 7 then return end
    local dd = true
    local serverTable = {}
    local serverid = nil
    for i = 0, 7 do
        if not sockets[i] then
            table.insert(serverTable, i)
            if dd then
                sockets[i] = data
                dd = false
            else

                sockets[i] = clone(data)
            end

            if #serverTable == num + 1 then break end

        end
        if i == 7 then
            log.info('socketCh395', 'No socket available ')
            for q = 1, #serverTable do sockets[serverTable[q]] = nil end
            return nil
        end
    end
    for i = 1, #serverTable do
        spiSend(spi.SPI_1, string.char(0x34, serverTable[i], 3))
        spiSend(spi.SPI_1, string.char(0x33, serverTable[i]) .. shorts(port))
        if i == 1 then
            spiSend(spi.SPI_1, string.char(0x35, serverTable[i]))
            sockets[i].id = serverTable[i]
            serverid = serverTable[i]
            local state = inquire2c(50)
            if state == '\x00' then
                sockets[serverTable[i]].id = serverTable[i]
                sockets[serverTable[i]].protocol = 'TCPSERVER'
            else
                log.info('socket open err', state:toHex())
                log.info('socketCh395', 'socket open err')
            end

        else
            local state = inquire2c(50)
            if state == '\x00' then
                log.info('socketCh395', 'server open' .. serverTable[i])

                sockets[serverTable[i]].protocol =
                    'TCPSERVERCLIENT' .. serverTable[i]
                sockets[serverTable[i]] = true

            end
            if i == num + 1 then
                spiSend(spi.SPI_1, string.char(0x36, serverid))
                local state = inquire2c(50)
                if state == '\x00' then return serverid end

            end
        end
    end

end

------------------------
local function errorInd(error)
    local coSuspended = {}

    for _, c in pairs(sockets) do -- IP状态出错时，通知所有已连接的socket
        if c ~= true then
            c.error = error
            -- 不能打开如下3行代码，IP出错时，会通知每个socket，socket会主动close
            -- 如果设置了connected=false，则主动close时，直接退出，不会执行close动作，导致core中的socket资源没释放
            -- 会引发core中socket耗尽以及socket id重复的问题
            -- c.connected = false
            -- socketsConnected = c.connected or socketsConnected
            -- if error == 'CLOSED' then sys.publish("SOCKET_ACTIVE", socketsConnected) end
            if c.co and coroutine.status(c.co) == "suspended" then
                -- coroutine.resume(c.co, false)
                table.insert(coSuspended, c.co)
            end
        end

    end

    for k, v in pairs(coSuspended) do
        if v and coroutine.status(v) == "suspended" then
            coroutine.resume(v, false, error)
        end
    end
end

sys.subscribe("IP_ERROR_IND", function() errorInd('IP_ERROR_IND') end)
-- sys.subscribe('IP_SHUT_IND', function()errorInd('CLOSED') end)
-- 创建socket函数
local mt = {}
mt.__index = mt
local function socket(protocol, cert, tCoreExtPara)
    local ssl = protocol:match("SSL")
    local co = coroutine.running()
    if not co then
        log.warn("socket.socket: socket must be called in coroutine")
        return nil
    end
    -- if protocol == 'TCPSERVER' and type(tCoreExtPara) == 'table' then
    --     protocol
    -- end
    -- 实例的属性参数表
    local o = {
        id = nil,
        protocol = protocol,
        tCoreExtPara = tCoreExtPara,
        ssl = ssl,
        cert = cert,
        co = co,
        input = {},
        output = {},
        wait = "",
        connected = false,
        iSubscribe = false,
        subMessage = nil,
        isBlock = false,
        msg = nil,
        rcvProcFnc = nil,
        sendstate = true, -- 发送缓冲区状态，true为空闲，可发送数据
        localPort = nil -- 本地端口
    }
    if tCoreExtPara and tCoreExtPara['localport'] and
        type(tCoreExtPara['localport']) == 'number' then
        o.localPort = tCoreExtPara['port']
    end
    if protocol == 'TCPSERVER' and tCoreExtPara['type'] == 'TCPSERVER' then
        o.port = configurationCh395["localPort"]
        local id = initServer(configurationCh395["localPort"],
                              configurationCh395["clientNum"],
                              setmetatable(o, mt))
        if not id then
            log.info('socketCh395', 'server socket err')
            return
        end
    elseif protocol == 'TCPSERVER' and tCoreExtPara['type'] ~= 'TCPSERVER' then
        o.address = tCoreExtPara['ip']
        o.port = tCoreExtPara['port']
        o.id = tCoreExtPara['id']
        o.protocol = 'TCPSERVERCLIENT'
        sockets[tCoreExtPara['id']] = setmetatable(o, mt)
    end
    return setmetatable(o, mt)
end

--- 创建基于TCP的socket对象
-- @bool[opt=nil] ssl，是否为ssl连接，true表示是，其余表示否
-- @table[opt=nil] cert，保留参数，ssl功能还未实现。
-- @table[opt=nil] tCoreExtPara, 建立链接扩展参数
-- {
--     id =0, --server socket索引ID
--     ip ="192.168.1.1", --server socket client ip
--     port ="8000", --server socket client port
--     type ="TCPSERVER", --server socket type
--     localport ="8000", -- socket client port
-- }
-- @return client，创建成功返回socket客户端对象；创建失败返回nil

function tcp(ssl, cert, tCoreExtPara)
    if tCoreExtPara and tCoreExtPara['type'] == "TCPSERVER" then
        return socket("TCPSERVER", nil, tCoreExtPara)
    elseif tCoreExtPara and tCoreExtPara['type'] ~= "TCPSERVER" then
        return socket("TCPSERVER", nil, tCoreExtPara)
    end
    return socket("TCP" .. (ssl == true and "SSL" or ""),
                  (ssl == true) and cert or nil, tCoreExtPara)
end

--- 创建基于UDP的socket对象
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage c = socket.udp()
function udp(localPort) return socket("UDP", nil, localPort) end

--- 连接服务器
-- @string address 服务器地址，支持ip和域名
-- @param port string或者number类型，服务器端口
-- @number[opt=120] timeout 可选参数，连接超时时间，单位秒
-- @return bool result true - 成功，false - 失败
-- @return string ,id '0' -- '8' ,返回通道ID编号
-- @usage  
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
function mt:connect(address, port, timeout)
    assert(self.co == coroutine.running(), "socket:connect: coroutine mismatch")
    log.info('socketCh395', 'socket data' .. self.protocol, address, port)
    if not link.isReady() then
        log.info("socket.connect: ip not ready")
        return false
    end

    self.address = address
    self.port = port
    local tCoreExtPara = self.tCoreExtPara or {}
    -- 默认缓冲区大小
    local rcvBufferSize = tCoreExtPara.rcvBufferSize or 0
    local d1, d2, d3, d4 = string.match(address, '(%d+)%.(%d+)%.(%d+).(%d+)')
    if not (d1 == nil or d2 == nil or d3 == nil or d4 == nil) then
        if self.protocol == 'TCP' then
            self.id = sockectCh395Conn(TCPCLIENT, address, port, self.localPort,
                                       self)

        elseif self.protocol == 'TCPSSL' then
            -- 未实现
            log.info("socketCh395", "no ssl")
        else
            self.id = sockectCh395Conn(UDPCLIENT, address, port, self.localPort,
                                       self)
        end
    else
        self.id = -2
    end
    if type(socketcore.sock_conn_ext) == "function" then
        if not self.id or self.id < 0 then
            if self.id == -2 then
                require "http"
                -- 请求腾讯云免费HttpDns解析
                http.request("GET", "119.29.29.29/d?dn=" .. address, nil, nil,
                             nil, 40000,
                             function(result, statusCode, head, body)
                    log.info("socket.httpDnsCb", result, statusCode, head, body)
                    sys.publish("SOCKET_HTTPDNS_RESULT_" .. address .. "_" ..
                                    port, result, statusCode, head, body)
                end)
                local _, result, statusCode, head, body = sys.waitUntil(
                                                              "SOCKET_HTTPDNS_RESULT_" ..
                                                                  address .. "_" ..
                                                                  port)

                -- DNS解析成功
                if result and statusCode == "200" and body and
                    body:match("^[%d%.]+") then
                    return self:connect(body:match("^([%d%.]+)"), port, timeout)
                end
            end
            self.id = nil
        end
    end
    if not self.id then
        log.info("socket:connect: core sock conn error", self.protocol, address,
                 port, self.cert)
        return false
    end
    log.info("socket:connect-coreid,prot,addr,port,cert,timeout", self.id,
             self.protocol, address, port, self.cert, timeout or 120)
    sockets[self.id] = self
    self.wait = "SOCKET_CONNECT"
    self.timerId = sys.timerStart(coroutine.resume, (timeout or 120) * 1000,
                                  self.co, false, "TIMEOUT")
    local result, reason = coroutine.yield()
    if not result and reason == 'server close' then return false end
    if self.timerId and reason ~= "TIMEOUT" then sys.timerStop(self.timerId) end
    if not result then
        log.info("socket:connect: connect fail" .. self.id, reason)
        if reason == "RESPONSE" then
            sockets[self.id] = nil
            self.id = nil
        end
        sys.publish("LIB_SOCKET_CONNECT_FAIL_IND", self.ssl, self.protocol,
                    address, port)
        return false
    end
    log.info("socket:connect: connect ok")

    if not self.connected then
        self.connected = true
        socketsConnected = socketsConnected + 1
        sys.publish("SOCKET_ACTIVE", socketsConnected > 0)
    end

    return true, self.id
end

function mt:serverClose()
    if not self then return false end
    if self.error then
        log.warn('socket.client:asyncSelect', 'error', self.error)
        return false
    end
    coroutine.resume(self.co, false, 'server close')
end

--- server发送数据
-- @number[opt=nil] keepAlive,服务器和客户端最大通信间隔时间,也叫心跳包最大时间,单位秒
-- @string[opt=nil] pingreq,心跳包的字符串
-- @return boole,false 失败，true 表示成功
-- @usage
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- while socketClient:serverSelect() do end
function mt:serverSelect(keepAlive, pingreq)
    assert(self.co == coroutine.running(),
           "socket:asyncSelect: coroutine mismatch")
    if self.error then
        log.warn('socket.client:asyncSelect', 'error', self.error)
        return false
    end
    self.wait = "SOCKET_SEND"
    local dataLen = 0
    -- log.info("socket.asyncSelect #self.output",#self.output)
    while #self.output ~= 0 do
        local data = table.concat(self.output)
        dataLen = string.len(data)
        self.output = {}
        local sendSize = SENDSIZE
        for i = 1, dataLen, sendSize do
            -- 按最大MTU单元对data分包
            sockectCh395Send(self.id, data:sub(i, i + sendSize - 1))
            if self.timeout then
                self.timerId = sys.timerStart(coroutine.resume,
                                              self.timeout * 1000, self.co,
                                              false, "TIMEOUT")
            end
            -- log.info("socket.asyncSelect self.timeout",self.timeout)
            local result, reason = coroutine.yield()
            if not result and reason == 'server close' then
                return false
            end
            log.info('发送结果', result, reason)
            if self.timerId and reason ~= "TIMEOUT" then
                sys.timerStop(self.timerId)
            end
            sys.publish("SOCKET_ASYNC_SEND", result)
            if not result then
                sys.publish("LIB_SOCKET_SEND_FAIL_IND", self.ssl, self.protocol,
                            self.address, self.port)
                log.warn('socket.asyncSelect', 'send error',
                         data:sub(i, i + sendSize - 1))
                return false
            end
        end
    end
    self.wait = "SOCKET_WAIT"
    -- log.info("socket.asyncSelect",dataLen,self.id)
    if dataLen > 0 then sys.publish("SOCKET_SEND", self.id, true) end
    if keepAlive and keepAlive ~= 0 then
        if type(pingreq) == "function" then
            sys.timerStart(pingreq, keepAlive * 1000)
        else
            sys.timerStart(self.asyncSend, keepAlive * 1000, self,
                           pingreq or "\0")
        end
    end
    local result, reason = coroutine.yield()
    if not result and reason == 'server close' then return false end
    return result, reason

end

--- 异步发送数据
-- @number[opt=nil] keepAlive,服务器和客户端最大通信间隔时间,也叫心跳包最大时间,单位秒
-- @string[opt=nil] pingreq,心跳包的字符串
-- @return boole,false 失败，true 表示成功
-- @usage
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- while socketClient:asyncSelect() do end
function mt:asyncSelect(keepAlive, pingreq)
    assert(self.co == coroutine.running(),
           "socket:asyncSelect: coroutine mismatch")
    if self.error then
        log.warn('socket.client:asyncSelect', 'error', self.error)
        return false
    end

    self.wait = "SOCKET_SEND"
    local dataLen = 0
    -- log.info("socket.asyncSelect #self.output",#self.output)
    while #self.output ~= 0 do
        local data = table.concat(self.output)
        dataLen = string.len(data)
        self.output = {}
        local sendSize = self.protocol == "UDP" and 1472 or SENDSIZE
        for i = 1, dataLen, sendSize do
            -- 按最大MTU单元对data分包
            socketcore.sock_send(self.id, data:sub(i, i + sendSize - 1))
            if self.timeout then
                self.timerId = sys.timerStart(coroutine.resume,
                                              self.timeout * 1000, self.co,
                                              false, "TIMEOUT")
            end
            -- log.info("socket.asyncSelect self.timeout",self.timeout)
            local result, reason = coroutine.yield()
            if not result and reason == 'server close' then
                return false
            end
            if self.timerId and reason ~= "TIMEOUT" then
                sys.timerStop(self.timerId)
            end
            sys.publish("SOCKET_ASYNC_SEND", result)
            if not result then
                sys.publish("LIB_SOCKET_SEND_FAIL_IND", self.ssl, self.protocol,
                            self.address, self.port)
                -- log.warn('socket.asyncSelect', 'send error')
                return false
            end
        end
    end
    self.wait = "SOCKET_WAIT"
    -- log.info("socket.asyncSelect",dataLen,self.id)
    if dataLen > 0 then sys.publish("SOCKET_SEND", self.id, true) end
    if keepAlive and keepAlive ~= 0 then
        if type(pingreq) == "function" then
            sys.timerStart(pingreq, keepAlive * 1000)
        else
            sys.timerStart(self.asyncSend, keepAlive * 1000, self,
                           pingreq or "\0")
        end
    end
    local result, reason = coroutine.yield()
    if not result and reason == 'server close' then return false end
    return result, reason
end

function mt:getAsyncSend()
    if self.error then return 0 end
    return #(self.output)
end

--- server缓存待发送的数据
-- @string data 数据
-- @number[opt=nil] timeout 可选参数，发送超时时间，单位秒；为nil时表示不支持timeout
-- @return result true - 成功，false - 失败
-- @usage
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- socketClient:serverSend("12345678")
function mt:serverSend(data, timeout)
    if self.error then
        log.warn('socket.client:asyncSend', 'error', self.error)
        return false
    end
    self.timeout = timeout
    table.insert(self.output, data or "")
    -- log.info("socket.asyncSend",self.wait)
    if self.wait == "SOCKET_WAIT" then coroutine.resume(self.co, true) end
    return true
end
--- server接收数据
-- @return data 表示接收到的数据(如果是UDP，返回最新的一包数据；如果是TCP,返回所有收到的数据)
--              ""表示未收到数据
-- @usage 
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- data = socketClient:serverRecv()
function mt:serverRecv()
    if #self.input == 0 then return "" end
    if self.protocol == "UDP" then
        return table.remove(self.input)
    else
        local s = table.concat(self.input)
        self.input = {}
        if self.isBlock then
            table.insert(self.input,
                         recv(self.msg.socket_index, self.msg.recv_len))
        end
        return s
    end
end

--- 异步缓存待发送的数据
-- @string data 数据
-- @number[opt=nil] timeout 可选参数，发送超时时间，单位秒；为nil时表示不支持timeout
-- @return result true - 成功，false - 失败
-- @usage
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- socketClient:asyncSend("12345678")
function mt:asyncSend(data, timeout)
    if self.error then
        log.warn('socket.client:asyncSend', 'error', self.error)
        return false
    end
    self.timeout = timeout
    table.insert(self.output, data or "")
    -- log.info("socket.asyncSend",self.wait)
    if self.wait == "SOCKET_WAIT" then coroutine.resume(self.co, true) end
    return true
end
--- 异步接收数据
-- @return data 表示接收到的数据(如果是UDP，返回最新的一包数据；如果是TCP,返回所有收到的数据)
--              ""表示未收到数据
-- @usage 
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- data = socketClient:asyncRecv()
function mt:asyncRecv()
    if #self.input == 0 then return "" end
    if self.protocol == "UDP" then
        return table.remove(self.input)
    else
        local s = table.concat(self.input)
        self.input = {}
        if self.isBlock then
            table.insert(self.input, socketcore.sock_recv(self.msg.socket_index,
                                                          self.msg.recv_len))
        end
        return s
    end
end

--- 同步发送数据
-- @string data 数据
--              此处传入的数据长度和剩余可用内存有关，只要内存够用，可以随便传入数据
--              虽然说此处的数据长度没有特别限制，但是调用core中的socket发送接口时，每次最多发送11200字节的数据
--              例如此处传入的data长度是112000字节，则在这个send接口中，会循环10次，每次发送11200字节的数据
-- @number[opt=120] timeout 可选参数，发送超时时间，单位秒
-- @return result true - 成功，false - 失败
-- @usage
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- socketClient:send("12345678")
function mt:send(data, timeout)
    assert(self.co == coroutine.running(), "socket:send: coroutine mismatch")
    if self.error then
        log.warn('socket.client:send', 'error', self.error)
        return false
    end
    log.debug("socket.send", "total " .. string.len(data or "") .. " bytes",
              "first 30 bytes", (data or ""):sub(1, 30))
    local sendSize = self.protocol == "UDP" and 1472 or SENDSIZE
    for i = 1, string.len(data or ""), sendSize do
        -- 按最大MTU单元对data分包
        self.wait = "SOCKET_SEND"
        sockectCh395Send(self.id, data:sub(i, i + sendSize - 1))
        self.timerId = sys.timerStart(coroutine.resume, (timeout or 120) * 1000,
                                      self.co, false, "TIMEOUT")
        local result, reason = coroutine.yield()
        if not result and reason == 'server close' then return false end
        if self.timerId and reason ~= "TIMEOUT" then
            sys.timerStop(self.timerId)
        end
        if not result then
            log.info("socket:send" .. self.id, "send fail", reason)
            sys.publish("LIB_SOCKET_SEND_FAIL_IND", self.ssl, self.protocol,
                        self.address, self.port)
            return false
        end
    end
    return true
end

--- 同步接收数据
-- @number[opt=0] timeout 可选参数，接收超时时间，单位毫秒
-- @string[opt=nil] msg 可选参数，控制socket所在的线程退出recv阻塞状态
-- @bool[opt=nil] msgNoResume 可选参数，控制socket所在的线程退出recv阻塞状态
--                false或者nil表示“在recv阻塞状态，收到msg消息，可以退出阻塞状态”，true表示不退出
--                此参数仅lib内部使用，应用脚本不要使用此参数
-- @return result 数据接收结果
--                true表示成功（接收到了数据）
--                false表示失败（没有接收到数据）
-- @return data 
--                如果result为true，data表示接收到的数据(如果是UDP，返回最新的一包数据；如果是TCP,返回所有收到的数据)
--                如果result为false，超时失败，data为"timeout"
--                如果result为false，msg控制退出，data为msg的字符串
--                如果result为false，socket连接被动断开控制退出，data为"CLOSED"
--                如果result为false，PDP断开连接控制退出，data为"IP_ERROR_IND"
-- @return param 如果是msg控制退出，param的值是msg的参数
-- @usage 
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- result,data = socketClient:recv(60000,"APP_SOCKET_SEND_DATA")
function mt:recv(timeout, msg, msgNoResume)
    assert(self.co == coroutine.running(), "socket:recv: coroutine mismatch")
    if self.error then
        log.warn('socket.client:recv', 'error', self.error)
        return false
    end
    self.msgNoResume = msgNoResume
    if msg and not self.iSubscribe then
        self.iSubscribe = msg
        self.subMessage = function(data)
            -- if data then table.insert(self.output, data) end
            if self.wait == "+RECEIVE" and not self.msgNoResume then
                if data then table.insert(self.output, data) end
                coroutine.resume(self.co, 0xAA)
            end
        end
        sys.subscribe(msg, self.subMessage)
    end
    if msg and #self.output > 0 then sys.publish(msg, false) end
    if #self.input == 0 then
        self.wait = "+RECEIVE"
        if timeout and timeout > 0 then
            local r, s = sys.wait(timeout)
            if r == nil then
                return false, "timeout"
            elseif r == 0xAA then
                local dat = table.concat(self.output)
                self.output = {}
                return false, msg, dat
            else
                return r, s
            end
        else
            local r, s = coroutine.yield()
            if not r and s == 'server close' then return false end
            if r == 0xAA then
                local dat = table.concat(self.output)
                self.output = {}
                return false, msg, dat
            else
                return r, s
            end
        end
    end

    if self.protocol == "UDP" then
        local s = table.remove(self.input)
        return true, s
    else
        log.warn("-------------------使用缓冲区---------------")
        local s = table.concat(self.input)
        self.input = {}
        if self.isBlock then
            table.insert(self.input, sockectCh395Recv(self.msg.socket_index,
                                                      self.msg.recv_len))
        end
        return true, s
    end
end

--- 主动关闭并且销毁一个socket
-- @return nil
-- @usage
-- socketClient = socket.tcp()
-- socketClient:connect("www.baidu.com","80")
-- socketClient:close()
function mt:close()
    assert(self.co == coroutine.running(), "socket:close: coroutine mismatch")
    if self.iSubscribe then
        sys.unsubscribe(self.iSubscribe, self.subMessage)
        self.iSubscribe = false
    end
    -- log.info('socketCh395', 'close' .. self.id)
    -- 此处不要再判断状态，否则在连接超时失败时，conneted状态仍然是未连接，会导致无法close
    -- if self.connected then
    log.info("socket:sock_close", self.id)
    local result, reason

    if self.id then
        sockectCh395Close(self.id)
        self.wait = "SOCKET_CLOSE"
        while true do
            result, reason = coroutine.yield()
            if not result and reason == 'server close' then
                return false
            end
            if reason == "RESPONSE" then break end
        end
    end
    if self.connected then
        self.connected = false
        if socketsConnected > 0 then
            socketsConnected = socketsConnected - 1
        end
        sys.publish("SOCKET_ACTIVE", socketsConnected > 0)
    end
    if self.input then self.input = {} end
    if self.protocol == 'TCPSERVERCLIENT' then
        sockets[self.id] = true
    else
        if self.id ~= nil then sockets[self.id] = nil end
    end

end

-- socket接收自定义控制处理
-- @function[opt=nil] rcvCbFnc，socket接收到数据后，执行的回调函数，回调函数的调用形式为：
-- rcvCbFnc(readFnc,socketIndex,rcvDataLen)
-- rcvCbFnc内部，会判断是否读取数据，如果读取，执行readFnc(socketIndex,rcvDataLen)，返回true；否则返回false或者nil
function mt:setRcvProc(rcvCbFnc)
    assert(self.co == coroutine.running(),
           "socket:setRcvProc: coroutine mismatch")
    self.rcvProcFnc = rcvCbFnc
end

function on_response(msg)
    local t = {
        [rtos.MSG_SOCK_CLOSE_CNF] = 'SOCKET_CLOSE',
        -- 33
        [rtos.MSG_SOCK_SEND_CNF] = 'SOCKET_SEND',
        -- 32
        [rtos.MSG_SOCK_CONN_CNF] = 'SOCKET_CONNECT'
        -- 34
    }
    if not sockets[msg.socket_index] then
        log.warn('response on nil socket', msg.socket_index, t[msg.id],
                 msg.result)
        return
    end
    if sockets[msg.socket_index] == true then return end
    log.info(sockets[msg.socket_index].wait, t[msg.id], msg.socket_index, msg.id)
    if sockets[msg.socket_index].wait ~= t[msg.id] then
        log.warn('response on invalid wait', sockets[msg.socket_index].id,
                 sockets[msg.socket_index].wait, t[msg.id], msg.socket_index)
        return
    end
    log.info('socket:on_response:', msg.socket_index, t[msg.id], msg.result)
    if sockets[msg.socket_index].protocol == 'TCPSERVERCLIENT' then
        msg.result = 0
    end
    coroutine.resume(sockets[msg.socket_index].co, msg.result == 0, 'RESPONSE')
end
sys.subscribe('SOCK_CONN_CNF', on_response)
sys.subscribe('SOCK_CLOSE_CNF', on_response)
sys.subscribe('SOCK_SEND_CNF', on_response)
-- 被动关闭
sys.subscribe('MSG_SOCK_CLOSE_IND', function(msg)
    local data = string.sub(spiSend(spi.SPI_1, string.char(0x2F,
                                                           msg.socket_index,
                                                           0xff, 0xff)), 3, -1)
    log.info('socketCh395', 'close socket ' .. msg.socket_index .. 'state',
             data:toHex())
    if string.sub(data, 1, 1) ~= '\x00' then return end
    log.info('socket.rtos.MSG_SOCK_CLOSE_IND', msg.socket_index)
    if not sockets[msg.socket_index] then
        return

    elseif sockets[msg.socket_index] == true then
        return
    elseif sockets[msg.socket_index].protocol == 'TCPSERVERCLIENT' then
        coroutine.resume(sockets[msg.socket_index].co, false, 'CLOSED')
        sockets[msg.socket_index] = true
        return
    end
    if not sockets[msg.socket_index] then
        log.warn('close ind on nil socket', msg.socket_index, msg.id)
        return
    end

    if sockets[msg.socket_index].connected then
        sockets[msg.socket_index].connected = false
        if socketsConnected > 0 then
            socketsConnected = socketsConnected - 1
        end
        sys.publish('SOCKET_ACTIVE', socketsConnected > 0)
    end

    sockets[msg.socket_index].error = 'CLOSED'
    --[[
    if type(socketcore.sock_destroy) == "function" then
        socketcore.sock_destroy(msg.socket_index)
    end]]
    sys.publish('LIB_SOCKET_CLOSE_IND', sockets[msg.socket_index].ssl,
                sockets[msg.socket_index].protocol,
                sockets[msg.socket_index].address,
                sockets[msg.socket_index].port)
    coroutine.resume(sockets[msg.socket_index].co, false, 'CLOSED')
end)
sys.subscribe('MSG_SOCK_RECV_IND', function(msg)
    if type(sockets[msg.socket_index]) ~= 'table' then
        log.warn('close ind on nil socket', msg.socket_index, msg.id)
        return
    end
    log.debug('socket.recv', msg.recv_len, sockets[msg.socket_index].rcvProcFnc)
    if sockets[msg.socket_index].rcvProcFnc then
        sockets[msg.socket_index].rcvProcFnc(msg.recv_data)
    else
        if sockets[msg.socket_index].wait == '+RECEIVE' then
            coroutine.resume(sockets[msg.socket_index].co, true, msg.recv_data)
        else -- 数据进缓冲区，缓冲区溢出采用覆盖模式
            if #sockets[msg.socket_index].input > INDEX_MAX then
                log.error('socket recv', 'out of stack', 'block')
                -- sockets[msg.socket_index].input = {}
                sockets[msg.socket_index].isBlock = true
                sockets[msg.socket_index].msg = msg
            else
                sockets[msg.socket_index].isBlock = false

                table.insert(sockets[msg.socket_index].input, msg.recv_data)
            end
            sys.publish('SOCKET_RECV', msg.socket_index)
        end
    end
end)

--- 设置TCP层自动重传的参数
-- @number[opt=4] retryCnt，重传次数；取值范围0到12
-- @number[opt=16] retryMaxTimeout，限制每次重传允许的最大超时时间(单位秒)，取值范围1到16
-- @return nil
-- @usage
-- setTcpResendPara(3,8)
-- setTcpResendPara(4,16)
function setTcpResendPara(retryCnt, retryMaxTimeout)
    ril.request("AT+TCPUSERPARAM=6," .. (retryCnt or 4) .. ",7200," ..
                    (retryMaxTimeout or 16))
end

--- 设置域名解析参数
-- 注意：0027以及之后的core版本才支持此功能
-- @number[opt=4] retryCnt，重传次数；取值范围1到8
-- @number[opt=4] retryTimeoutMulti，重传超时时间倍数，取值范围1到5
--                第n次重传超时时间的计算方式为：第n次的重传超时基数*retryTimeoutMulti，单位为秒
--                重传超时基数表为{1, 1, 2, 4, 4, 4, 4, 4}
--                第1次重传超时时间为：1*retryTimeoutMulti 秒
--                第2次重传超时时间为：1*retryTimeoutMulti 秒
--                第3次重传超时时间为：2*retryTimeoutMulti 秒
--                ...........................................
--                第8次重传超时时间为：8*retryTimeoutMulti 秒
-- @return nil
-- @usage
-- socket.setDnsParsePara(8,5)
function setDnsParsePara(retryCnt, retryTimeoutMulti)
    ril.request("AT*DNSTMOUT=" .. (retryCnt or 4) .. "," ..
                    (retryTimeoutMulti or 4))
end

--- 打印所有socket的状态
-- @return 无
-- @usage socket.printStatus()
function printStatus()
    for _, client in pairs(sockets) do
        for k, v in pairs(client) do
            log.info('socket.printStatus', 'client', client.id, k, v)
        end
    end
end

--- 设置数据传输后，允许进入休眠状态的延时时长
-- 3024版本以及之后的版本才支持此功能
-- 此功能设置的参数，设置成功后，掉电会自动保存
-- @number tm，数据传输后，允许进入休眠状态的延时时长，单位为秒，取值范围1到20
--             注意：此时间越短，允许进入休眠状态越快，功耗越低；但是在某些网络环境中，此时间越短，可能会造成数据传输不稳定
--                   建议在可以接受的功耗范围内，此值设置的越大越好
--                   如果没有设置此参数，此延时时长是和基站的配置有关，一般来说是10秒左右
-- @return nil
-- @usage
-- socket.setLowPower(5)
function setLowPower(tm) ril.request("AT*RTIME=" .. tm) end
