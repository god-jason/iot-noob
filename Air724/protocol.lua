--- 模块功能：链接管理
-- @module link
-- @author 杰神
-- @license GPLv3
-- @copyright zgwit
-- @release 2023.06.30
module(..., package.seeall)

local MOD = "PROTOCOL"

local protocols = {
    require("protocols.modbus").modbus
}
