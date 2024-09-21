#!/bin/bash

set -e  # 遇到错误时立即退出
set -u  # 使用未定义变量时报错

# 函数：输出消息
log() {
    echo "[$(date +'%F %T')] $1"
}

# 1. 更新源代码
log "更新源代码..."
git pull

# 2. 更新 feeds
log "更新 Feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 替换插件
log "替换插件..."
PLUGIN_DIR="feeds/luci/applications/luci-app-homeproxy"
if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
fi

# 使用 Git 克隆 master 分支的插件
git clone --branch master https://github.com/bulianglin/homeproxy.git "$PLUGIN_DIR"

# 检查克隆是否成功
if [ ! -d "$PLUGIN_DIR" ] || [ -z "$(ls -A "$PLUGIN_DIR")" ]; then
    echo "错误：插件克隆失败或目录为空，请检查仓库 URL 和网络连接。"
    exit 1
fi

# 4. 添加固件日期
log "添加固件日期..."
BUILD_DATE_PREFIX=$(date +%F)  # 设置 BUILD_DATE_PREFIX 变量为当前日期
sed -i "s/IMG_PREFIX:=/IMG_PREFIX:=${BUILD_DATE_PREFIX}-/g" ./include/image.mk

# 检查并添加 BUILD_DATE_PREFIX 到 image.mk 文件
if ! grep -q "BUILD_DATE_PREFIX" ./include/image.mk; then
    log "添加 BUILD_DATE_PREFIX 到 image.mk 文件..."
    sed -i "/DTS_DIR:=$(LINUX_DIR)/a BUILD_DATE_PREFIX := \$(shell date +'%F')" ./include/image.mk
fi

# 5. 修改固件时区
log "修改固件时区..."
sed -i 's/UTC/UTC-8/g' package/base-files/files/bin/config_generate

# 6. 配置编译选项（可选）
# 如果需要通过 menuconfig 进行额外配置，请取消注释以下行
# log "打开 menuconfig 进行额外配置..."
# make menuconfig

log "所有步骤完成！"
