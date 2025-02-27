local tag = "NET"

function net_status()
    local ret = mobile.scell()
    ret['csq'] = mobile.csq()
    return ret
end

sys.subscribe("SIM_IND", function(status)
    -- status的取值有:
    -- RDY SIM卡就绪
    -- NORDY 无SIM卡
    -- SIM_PIN 需要输入PIN
    -- GET_NUMBER 获取到电话号码(不一定有值)
    log.info("sim status", status)
end)
