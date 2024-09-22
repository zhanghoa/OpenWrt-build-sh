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

# 删除旧的插件目录（如果存在）
if [ -d "$PLUGIN_DIR" ]; then
    log "删除旧的插件目录: $PLUGIN_DIR"
    rm -rf "$PLUGIN_DIR"
fi

# 使用 Git 克隆新的插件
log "克隆新的插件仓库到: $PLUGIN_DIR"
git clone -b master https://github.com/bulianglin/homeproxy.git "$PLUGIN_DIR"

# 检查克隆是否成功
if [ ! -d "$PLUGIN_DIR/.git" ]; then
    log "错误：克隆失败，请检查网络连接或目标仓库的有效性。"
    exit 1
else
    LAST_COMMIT=$(cd "$PLUGIN_DIR" && git log -1 --pretty=format:"%H")
    log "克隆成功，最后一次提交为: $LAST_COMMIT"
fi

# 4. 添加固件日期
log "添加固件日期..."

# 检查并添加 BUILD_DATE_PREFIX
if ! grep -q "BUILD_DATE_PREFIX :=" ./include/image.mk; then
    log "添加 BUILD_DATE_PREFIX 到 image.mk 文件..."
    sed -i '/DTS_DIR:=$(LINUX_DIR)/a\
BUILD_DATE_PREFIX := \$(shell date +'\''%F'\'')' ./include/image.mk
else
    # 如果 BUILD_DATE_PREFIX 已经存在
    log "BUILD_DATE_PREFIX 已经存在。"
fi


# 检查 IMG_PREFIX 是否已包含 BUILD_DATE_PREFIX
if grep -q "IMG_PREFIX:=\$(BUILD_DATE_PREFIX)-" ./include/image.mk; then
    log "IMG_PREFIX 已经包含。"
else
    log "替换 IMG_PREFIX..."
    if grep -q "IMG_PREFIX:=" ./include/image.mk; then
        sed -i "s/IMG_PREFIX:=/IMG_PREFIX:=\$(BUILD_DATE_PREFIX)-/g" ./include/image.mk
        log "IMG_PREFIX 替换成功。"
    else
        log "未找到 IMG_PREFIX 定义，无法进行替换。"
    fi
fi

# 5. 修改固件时区
log "修改固件时区..."
sed -i 's/UTC/UTC-8/g' package/base-files/files/bin/config_generate

# 6. 配置编译选项（可选）
# 如果需要通过 menuconfig 进行额外配置，请取消注释以下行
# log "打开 menuconfig 进行额外配置..."
# make menuconfig

log "所有步骤完成！"
