#!/bin/bash

tar -czf huahai-mbus-gateway.tar.gz \
    *.lua \
    *.json \
    ../../core/* \
    ../../links/link_serial.lua \
    ../../protocols/protocol_cjt188.lua \
    ../../protocols/protocol_modbus.lua


