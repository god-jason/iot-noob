#!/bin/bash


tmp="gateway"
filename="huahai-mbus-gateway-$(date +%Y%m%d-%H%M%S).tar.gz"

#创建临时目录
mkdir $tmp

#复制相关源文件
cp \
    *.lua \
    *.json \
    ../../core/* \
    ../../links/* \
    ../../protocols/* \
    ../../platforms/luatos/* \
    $tmp

#删除空白文件
find $tmp -type f -empty -delete

#打包
tar -czvf $filename $tmp

#删除临时目录
rm $tmp -rf

