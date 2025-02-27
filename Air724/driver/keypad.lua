--- 模块功能：按键处理
-- @module keypad
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30

module(..., package.seeall)

local MOD = "KEYPAD"


-- 定义按键表，可以从配置中读取
local KEYMAP =
{
    ["53"] = "1", ["52"] = "2", ["51"] = "3", ["50"] = "A",
    ["43"] = "4", ["42"] = "5", ["41"] = "6", ["40"] = "B",
    ["33"] = "7", ["32"] = "8", ["31"] = "9", ["30"] = "C",
    ["23"] = "*", ["22"] = "0", ["21"] = "#", ["20"] = "D",
    ["255255"] = "开关机"
}


-- 按键消息处理函数
local function onKeyMsg(msg)
    -- 保存按键名
    -- msg.key_matrix_row：行索引
    -- msg.key_matrix_col：列索引
    log.info("KEYPAD", msg.key_matrix_row, msg.key_matrix_col, msg.pressed)
    local key = KEYMAP[msg.key_matrix_row..msg.key_matrix_col]

    sys.publish("KEYPAD", key, msg.pressed, msg.key_matrix_row, msg.key_matrix_col)
end

rtos.on(rtos.MSG_KEYPAD, onKeyMsg)

--第一个参数：固定为rtos.MOD_KEYPAD，表示键盘  
--第二个参数：目前无意义，固定为0  
--第三个参数：键盘阵列keyin标记，例如使用了keyin2、keyin3、keyin4、keyin5，则第三个参数为1<<2|1<<3|1<<4|1<<5 = 0x3C    行
--第四个参数：键盘阵列keyout标记，例如使用了keyout0、keyout1、keyout2、keyout3，则第四个参数为1<<0|1<<1|1<<2|1<<3 = 0x0F  列
rtos.init_module(rtos.MOD_KEYPAD,0,0x3c,0x0F)

