#!/bin/bash

# 1. 更新源代码
git pull

# 2. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 5. 添加固件日期
sed -i 's/IMG_PREFIX:=/IMG_PREFIX:=$(BUILD_DATE_PREFIX)-/g' ./include/image.mk
sed -i '/DTS_DIR:=$(LINUX_DIR)/a\BUILD_DATE_PREFIX := $(shell date +\'%F\')' ./include/image.mk

# 8. 修改固件时区
sed -i 's/UTC/UTC-8/g' package/base-files/files/bin/config_generate

# 9. 配置编译选项（可选）
# 如果需要通过 menuconfig 进行额外配置，请取消注释以下行
make menuconfig

# 10. 编译固件
# make -j$(nproc)
