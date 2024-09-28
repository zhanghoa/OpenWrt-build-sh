#!/bin/bash

set -e  # 遇到错误时立即退出
set -u  # 使用未定义变量时报错

# 函数：输出消息
log() {
    echo "[$(date +'%F %T')] $1"
}

# 函数：询问用户是否执行某一步骤，默认选择“否”
ask_user() {
    local prompt="$1"
    while true; do
        read -p "$prompt [y/n, 默认 n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]*|"" ) return 1;;  # 如果用户直接按回车，默认为“否”
            * ) echo "请输入 y 或 n."
        esac
    done
}

# 主流程
main() {
    # 定义 TEMP_CLONE_DIR 变量
    TEMP_CLONE_DIR="/tmp/homeproxy-clone"

    # 1. 更新源代码
    if ask_user "是否要更新源代码？"; then
        log "更新源代码..."
        git pull
    fi

    # 2. 添加 istore 插件
    if ask_user "是否要添加 istore 插件？"; then
        log "添加 istore 插件..."
        # 检查是否已经存在 istore 的配置
        if ! grep -q "src-git istore" feeds.conf.default; then
            echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default
            log "istore 插件已添加到 feeds.conf.default。"

            # 如果添加了新的插件，需要重新安装 Feeds
            ./scripts/feeds update -a
            ./scripts/feeds install -a
        else
            log "istore 插件已经在 feeds.conf.default 中，无需重复添加。"
        fi
    fi

    # 3. 更新 feeds
    if ask_user "是否要更新 Feeds？"; then
        log "更新 Feeds..."
        ./scripts/feeds update -a
        ./scripts/feeds install -a
    fi

    # 4. 替换插件
    if ask_user "是否要替换插件？"; then
        log "替换插件..."
        PLUGIN_DIR="feeds/luci/applications/luci-app-homeproxy"

        if [ ! -d "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR/.git" ]; then
            log "克隆新的插件仓库到: $TEMP_CLONE_DIR"
            git clone -b master https://github.com/bulianglin/homeproxy.git "$TEMP_CLONE_DIR"
            if [ ! -d "$TEMP_CLONE_DIR/.git" ]; then
                log "错误：克隆失败，请检查网络连接或目标仓库的有效性。"
                exit 1
            else
                LAST_COMMIT=$(cd "$TEMP_CLONE_DIR" && git log -1 --pretty=format:"%H")
                log "克隆成功，最后一次提交为: $LAST_COMMIT"
                
                if [ -d "$PLUGIN_DIR" ]; then
                    log "删除旧的插件目录: $PLUGIN_DIR"
                    rm -rf "$PLUGIN_DIR"
                fi

                mv "$TEMP_CLONE_DIR" "$PLUGIN_DIR"
                log "新插件已安装到: $PLUGIN_DIR"

                # 如果替换了插件，需要重新安装 Feeds
                ./scripts/feeds update -a
                ./scripts/feeds install -a
            fi
        else
            cd "$PLUGIN_DIR"
            LOCAL_COMMIT=$(git log -1 --pretty=format:"%H")
            REMOTE_COMMIT=$(git ls-remote origin master | awk '{print $1}')
            if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                log "检测到远程有新的提交，开始更新插件..."
                git pull
                LAST_COMMIT=$(git log -1 --pretty=format:"%H")
                log "更新完成，最后一次提交为: $LAST_COMMIT"

                # 如果更新了插件，需要重新安装 Feeds
                ./scripts/feeds update -a
                ./scripts/feeds install -a
            else
                log "本地插件已是最新版本，无需更新。"
            fi
            cd -
        fi
    fi

    # 清理临时目录（如果存在）
    if [ -d "$TEMP_CLONE_DIR" ]; then
        rm -rf "$TEMP_CLONE_DIR"
    fi

    # 5. 添加固件日期
    if ask_user "是否要添加固件日期？"; then
        log "添加固件日期..."
        # 检查并添加 BUILD_DATE_PREFIX
        if ! grep -q "BUILD_DATE_PREFIX :=" ./include/image.mk; then
            log "添加 BUILD_DATE_PREFIX 到 image.mk 文件..."
            sed -i '/DTS_DIR:=$(LINUX_DIR)/a\
BUILD_DATE_PREFIX := \$(shell date +'\''%F'\'')' ./include/image.mk
        else
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
    fi

    # 6. 修改固件时区
    if ask_user "是否要修改固件时区？"; then
        log "修改固件时区..."
        if ! grep -q "UTC-8" package/base-files/files/bin/config_generate; then
            sed -i 's/UTC/UTC-8/g' package/base-files/files/bin/config_generate
            log "固件时区已修改为 UTC-8。"
        else
            log "固件时区已经是 UTC-8，无需修改。"
        fi
    fi

    # 7. 修改默认IP
    if ask_user "是否要修改默认IP？"; then
        # 文件路径
        file_path="package/base-files/files/bin/config_generate"

        # 读取现有 IP 地址
        old_ip=$(grep -oP 'lan\) ipad=\$\{ipaddr:-"\K[^"]+' "$file_path")

        # 检查是否找到 IP 地址
        if [ -z "$old_ip" ]; then
            log "没有找到现有的IP地址。"
            exit 1
        fi

        # 输出现有 IP 地址
        log "当前IP地址: $old_ip"

        # 提示用户输入新的 IP 地址
        read -p "请输入新的IP地址: " new_ip

        # 验证新IP地址格式
        if ! [[ $new_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log "无效的IP地址格式。"
            exit 1
        fi

        # 使用 sed 进行替换
        sed -i "s/${old_ip}/${new_ip}/g" "$file_path"

        log "IP地址已更新为 $new_ip 在文件 $file_path 中。"
    fi

    # 8. TTYD 免登录配置
    if ask_user "是否要配置 TTYD 免登录？"; then
        log "配置 TTYD 免登录..."
        if ! grep -q "/bin/login -f root" feeds/packages/utils/ttyd/files/ttyd.config; then
            sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config
            log "TTYD 免登录配置完成。"
        else
            log "TTYD 免登录配置已经完成，无需再次修改。"
        fi
    fi

    # 9. 调整 Docker 到 服务 菜单
    if ask_user "是否要将 Docker 移动到 服务 菜单？"; then
        log "调整 Docker 到 服务 菜单..."
        if ! grep -q '"admin", "services"' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua; then
            sed -i 's/"admin"/"admin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua
            sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
            sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
            sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm
            log "Docker 已移动到 服务 菜单。"
        else
            log "Docker 已经在 服务 菜单中，无需再次修改。"
        fi
    fi

    # 10. 调整 ZeroTier 到 服务 菜单
    if ask_user "是否要将 ZeroTier 移动到 服务 菜单？"; then
        log "调整 ZeroTier 到 服务 菜单..."
        if ! grep -q 'services' feeds/luci/applications/luci-app-zerotier/root/usr/share/luci/menu.d/luci-app-zerotier.json; then
            sed -i 's/vpn/services/g; s/VPN/Services/g' feeds/luci/applications/luci-app-zerotier/root/usr/share/luci/menu.d/luci-app-zerotier.json
            log "ZeroTier 已移动到 服务 菜单。"
        else
            log "ZeroTier 已经在 服务 菜单中，无需再次修改。"
        fi
    fi

    # 11. 生成默认配置文件
    if ask_user "是否要生成默认配置文件 (make defconfig)？"; then
        log "生成默认配置文件..."
        make defconfig
    fi

    # 12. 下载源代码包
    if ask_user "是否要下载源代码包 (make download -j32)？"; then
        log "下载源代码包..."
        make download -j32
    fi

    # 13. 配置编译选项（可选）
    if ask_user "是否要通过 menuconfig 进行额外配置？"; then
        log "打开 menuconfig 进行额外配置..."
        make menuconfig
    fi

    log "所有步骤完成！"
}

# 执行主流程
main
