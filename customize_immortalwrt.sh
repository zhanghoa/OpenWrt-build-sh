#!/bin/bash

# 1. 更新源代码
git pull

# 2. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 设置密码为空
sed -i '/CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings

# 4. 修改时间格式
sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 5. 添加固件日期
sed -i 's/IMG_PREFIX:=/IMG_PREFIX:=$(BUILD_DATE_PREFIX)-/g' ./include/image.mk
sed -i '/DTS_DIR:=$(LINUX_DIR)/a\BUILD_DATE_PREFIX := $(shell date +\'%F\')' ./include/image.mk

# 6. 修正硬件信息
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 7. 增加固件连接数
sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=165535' package/base-files/files/etc/sysctl.conf

# 8. 修改固件时区
sed -i 's/UTC/UTC-8/g' package/base-files/files/bin/config_generate

# 9. 配置编译选项（可选）
# 如果需要通过 menuconfig 进行额外配置，请取消注释以下行
make menuconfig

# 10. 编译固件
# make -j$(nproc)
