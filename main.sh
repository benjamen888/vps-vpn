#!/bin/sh

if [[ $EUID -ne 0 ]]; then
    clear
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

# 检查curl是否已安装，如果没有则安装
check_and_install_curl() {
    if ! command -v curl &> /dev/null; then
        echo "curl未安装，开始安装..."
        if [ -f "/usr/bin/apt-get" ]; then
            apt-get update -y
            apt-get install -y curl
        else
            yum update -y
            yum install -y curl
        fi
        echo "curl已安装完成"
    else
        echo "curl已经安装，跳过安装步骤"
    fi
}

# 脚本开始时检查curl
check_and_install_curl

installHysteria2(){
    wget https://raw.githubusercontent.com/benjamen888/vps-vpn/main/proxytype/hy2.sh && bash hy2.sh    
}

unInstallHysteria2(){
    bash <(curl -fsSL https://get.hy2.sh/) --remove
    rm -rf /etc/hysteria
}

retRouting(){
	curl https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -sSf | sh
}

installReality(){
    # 定义可选的国家列表及其对应的网站参数
    echo "--------------------------------------------------"
    echo "请选择 Reality 配置的目标网站:"
    echo "1. sg (新加坡 )"
    echo "2. hk (香港 )"
    echo "3. jp (日本 )"
    echo "4. tw (台湾 )"
    echo "5. us (美国 )"
    echo -n "请输入选项数字或国家代码 (例如: sg)。直接回车将使用默认 (sg):"
    read -r country_choice

    # 默认为sg
    country="unknow"
    
    # 根据用户输入确定国家代码
    if [[ -n "$country_choice" ]]; then
        case "$country_choice" in
            1|"sg") country="sg" ;;
            2|"hk") country="hk" ;;
            3|"jp") country="jp" ;;
            4|"tw") country="tw" ;;
            5|"us") country="us" ;;
            *) echo "输入的选项 '$country_choice' 无效，将使用默认 (www.amazon.com)。" ;;
        esac
    fi
    
    # 根据国家代码设置网站
    case "$country" in
        "sg") website="www.stb.gov.sg" ;;
        "hk") website="www.gov.hk" ;;
        "jp") website="media-server.clubmed.com" ;;
        "tw") website="tw.trip.com" ;;
        "us") website="www.ucdavis.edu" ;;
        *) website="www.amazon.com" ;;
    esac
    
    echo "--------------------------------------------------"
    echo "已选择国家: $country"
    echo "将使用的网站: $website"
    echo "--------------------------------------------------"
    
    # 下载并执行reality.sh，传递网站参数
    wget https://raw.githubusercontent.com/benjamen888/vps-vpn/main/proxytype/reality.sh
    
    echo "开始执行 reality.sh 并传递参数..."
    echo "执行命令: bash reality.sh \"$website\""
    
    # 直接执行reality.sh并传递参数
    bash reality.sh "$website"
}
unInstallReality()
{
	systemctl stop xray
	bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
	rm -rf /usr/local/etc/xray
	rm -rf /var/log/xray
}

useRSAandDisablePassword()
{

    # 定义 SSH 配置文件路径
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # 备份原配置文件
    cp $SSHD_CONFIG "${SSHD_CONFIG}.bak"

    # 禁用密码登录，强制密钥登录
    echo "禁用密码登录，强制使用密钥登录..."
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' $SSHD_CONFIG
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' $SSHD_CONFIG
    sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' $SSHD_CONFIG
    sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' $SSHD_CONFIG

    # 检查是否已经启用密钥登录
    grep -q '^PubkeyAuthentication yes' $SSHD_CONFIG
    if [ $? -ne 0 ]; then
        echo "PubkeyAuthentication yes" >> $SSHD_CONFIG
    fi

    # 重新启动 SSH 服务应用更改
    echo "重新启动 SSH 服务..."
    systemctl restart sshd

    # 提示用户更改已完成
    echo "密码登录已禁用，仅能使用密钥登录。"

}
disableNzaSSh()
{
	CONFIG_FILE="/opt/nezha/agent/config.yml"

	# 检查文件是否存在
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "❌ 配置文件 $CONFIG_FILE 不存在！请检查 Nezha Agent 是否已安装。"
		exit 1
	fi

	# 修改配置文件（如果不存在该字段，则添加）
	if grep -q "disable_command_execute" "$CONFIG_FILE"; then
		sed -i 's/disable_command_execute:.*/disable_command_execute: true/' "$CONFIG_FILE"
	else
		echo "disable_command_execute: true" >> "$CONFIG_FILE"
	fi

	echo "✅ 配置已修改：禁用远程命令执行"

	# 重新加载 systemd 并重启 Nezha Agent
	systemctl daemon-reload
	systemctl restart nezha-agent

	# 检查服务状态
	if systemctl is-active --quiet nezha-agent; then
		echo "✅ Nezha Agent 已成功重启并运行中！"
	else
		echo "❌ Nezha Agent 启动失败，请手动检查。"
	fi

}

configure_network() {
    SYSCTL_CONF="/etc/sysctl.conf"
    sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
    sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/net.ipv6.conf.lo.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/net.ipv4.tcp_rmem/d' "$SYSCTL_CONF"
    sed -i '/net.ipv4.tcp_wmem/d' "$SYSCTL_CONF"
    sed -i '/net.core.rmem_max/d' "$SYSCTL_CONF"
    sed -i '/net.core.wmem_max/d' "$SYSCTL_CONF"
    
    echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" >> "$SYSCTL_CONF"
    echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1\nnet.ipv6.conf.lo.disable_ipv6=1" >> "$SYSCTL_CONF"
    echo -e "net.ipv4.tcp_rmem = 4096 2097152 4194304\nnet.ipv4.tcp_wmem = 4096 2097152 4194304" >> "$SYSCTL_CONF"
    echo -e "net.core.rmem_max=4194304\nnet.core.wmem_max=4194304" >> "$SYSCTL_CONF"
    
    sysctl -p
    echo "BBR 拥塞控制已启用，IPv6 已禁用，网络优化已应用。"
}

install3xui(){
	sudo apt update
	sudo apt install curl
	bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

# 新增功能：配置系统 SWAP
configure_swap() {
    # 默认 SWAP 大小为 2G
    SWAP_SIZE="${1:-2}"
    
    # 检查是否为 Debian 系统
    if [ -f /etc/debian_version ]; then
        echo "正在为 Debian 系统配置 SWAP..."
    else
        echo "警告：当前不是 Debian 系统，但仍将尝试配置 SWAP。"
    fi
    
    # 检查是否已存在 SWAP
    if grep -q swap /etc/fstab; then
        echo "系统中已存在 SWAP 配置，是否要删除并重新创建？[y/n]"
        read -r answer
        if [ "$answer" = "y" ]; then
            # 关闭现有 SWAP
            swapoff -a
            # 从 fstab 中删除 SWAP 条目
            sed -i '/swap/d' /etc/fstab
            echo "已删除现有 SWAP 配置。"
        else
            echo "操作已取消。"
            return 1
        fi
    fi
    
    # 检查可用磁盘空间
    FREE_DISK=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$FREE_DISK" -lt "$SWAP_SIZE" ]; then
        echo "警告：可用磁盘空间 (${FREE_DISK}G) 小于请求的 SWAP 大小 (${SWAP_SIZE}G)。"
        echo "是否继续？[y/n]"
        read -r answer
        if [ "$answer" != "y" ]; then
            echo "操作已取消。"
            return 1
        fi
    fi
    
    # 创建 SWAP 文件 - 使用更小的块大小和块数量来避免内存耗尽
    echo "正在创建 ${SWAP_SIZE}G 的 SWAP 文件..."
    # 使用小块大小创建以避免内存耗尽
    dd if=/dev/zero of=/swapfile bs=64M count=$((SWAP_SIZE * 16)) status=progress
    
    # 检查 dd 命令是否成功
    if [ $? -ne 0 ]; then
        echo "创建 SWAP 文件失败，尝试使用备用方法..."
        # 备用方法：使用 fallocate
        fallocate -l ${SWAP_SIZE}G /swapfile
        
        if [ $? -ne 0 ]; then
            echo "❌ SWAP 文件创建失败！请检查磁盘空间和权限。"
            return 1
        fi
    fi
    
    # 设置权限并创建 SWAP
    echo "设置 SWAP 文件权限..."
    chmod 600 /swapfile
    
    echo "格式化 SWAP 文件..."
    mkswap /swapfile
    
    # 检查 mkswap 是否成功
    if [ $? -ne 0 ]; then
        echo "❌ SWAP 文件格式化失败！"
        rm -f /swapfile
        return 1
    fi
    
    echo "激活 SWAP..."
    swapon /swapfile
    
    # 检查 swapon 是否成功
    if [ $? -ne 0 ]; then
        echo "❌ SWAP 激活失败！"
        rm -f /swapfile
        return 1
    fi
    
    # 添加到 fstab 以在重启后自动挂载
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    
    # 调整 swappiness 和 cache pressure 参数
    echo "正在优化内存管理参数..."
    grep -q "vm.swappiness" /etc/sysctl.conf && sed -i '/vm.swappiness/d' /etc/sysctl.conf
    grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf && sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf
    
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    sysctl -p
    
    # 显示 SWAP 信息
    echo "SWAP 配置已完成！当前 SWAP 状态："
    free -h | grep -i swap
    
    echo "SWAP 配置已成功添加到系统，大小为 ${SWAP_SIZE}G。"
    echo "按任意键返回主菜单..."
    read -n 1
}

installShadowsocks(){
    wget https://raw.githubusercontent.com/benjamen888/vps-vpn/main/proxytype/ss-rust.sh && bash ss-rust.sh
    echo "按任意键返回主菜单..."
    read -n 1
    runmenu
}

runBestTrace(){
    # 安装 nexttrace
    if [ ! -f "/usr/local/bin/nexttrace" ]; then
        curl nxtrace.org/nt | bash
    fi

    next() {
        printf "%-70s\n" "-" | sed 's/\s/-/g'
    }

    clear
    next

    ip_list=(58.60.188.222 210.21.196.6 120.196.165.24)
    ip_addr=(深圳电信 深圳联通 深圳移动)

    for i in {0..2}
    do
        echo ${ip_addr[$i]}
        nexttrace -M ${ip_list[$i]}
        next
    done
}

setLlAlias(){
    # 检查是否已存在别名设置
    if ! grep -q "alias ll='ls -l'" ~/.bashrc; then
        echo "alias ll='ls -l'" >> ~/.bashrc
        echo "已添加 ll 别名命令到 ~/.bashrc"
    else
        echo "ll 别名命令已存在于 ~/.bashrc"
    fi
    
    # 使用source命令重新加载.bashrc
    source ~/.bashrc
    
    # 同时在当前会话中直接设置别名
    alias ll='ls -l'
    
    echo "ll 别名命令已经设置完成"
    echo "您现在可以使用 ll 命令了"
}

checkNetworkQuality(){
    bash <(curl -sL IP.Check.Place)
}

checkStreamingUnlock(){
    bash <(curl -L -s media.ispvps.com)
}

viewRealityConfig(){
    cat /usr/local/etc/xray/reclient.json
    echo "按任意键返回主菜单..."
    read -n 1
    runmenu
}

installNextTrace(){
    echo "🧠 正在检测系统架构..."
    ARCH=$(uname -m)

    if [[ "$ARCH" == "x86_64" ]]; then
        TARGET="linux_amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        TARGET="aarch64-unknown-linux-gnu"
    else
        echo "❌ 不支持的架构: $ARCH"
        return 1
    fi

    echo "📡 正在获取最新版本..."
    LATEST_VERSION=$(wget -qO- https://api.github.com/repos/nxtrace/NTrace-core/releases | grep -m 1 '"tag_name":' | cut -d '"' -f 4)

    if [ -z "$LATEST_VERSION" ]; then
        echo "❌ 无法获取最新版本号，请检查网络连接或 GitHub API 限制"
        return 1
    fi

    echo "📦 最新版本: $LATEST_VERSION"
    ZIP_NAME="nexttrace_${TARGET}"
    DOWNLOAD_URL="https://github.com/nxtrace/Ntrace-core/releases/download/${LATEST_VERSION}/${ZIP_NAME}"

    echo "🌐 下载链接: $DOWNLOAD_URL"

    TMP_DIR="/tmp/nexttrace_install"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "📥 正在下载..."
    wget -q --show-progress "$DOWNLOAD_URL" -O "$ZIP_NAME" || { echo "❌ 下载失败，请确认该版本支持你的架构"; return 1; }

    echo "🚀 安装 nexttrace 到 /usr/local/bin/..."
    mv -f $ZIP_NAME /usr/local/bin/nexttrace
    chmod +x /usr/local/bin/nexttrace

    echo "🧹 清理..."
    cd ~
    rm -rf "$TMP_DIR"

    echo "✅ 安装成功！版本如下："
    nexttrace -v
    
    echo "按任意键返回主菜单..."
    read -n 1
    runmenu
}

runmenu(){
    clear
    echo " ================================================== "
    echo " 介绍：一键安装 Reality和hy2代理    "
    echo " 系统：Ubuntu、Debian、CentOS                        "
    echo " ================================================== "
    echo " 1. 安装 Reality"
    echo " 2. 安装 Hysteria2"
    echo " 3. 关闭密码登陆，启用密钥登陆"
	echo " 4. 关闭哪吒ssh远程登录"
	echo " 5. 关闭ipv6并且开启BBR拥塞算法"	
    echo " 6. 安装3x-ui	"
    echo " 7. 配置系统 SWAP (默认2G)"
    echo " 8. 安装 Shadowsocks"
    echo " ------------------------------------"
    echo " 11. 卸载 Reality"
    echo " 12. 卸载 Hysteria2"
    echo " 13. 测试网络质量"
    echo " 14. 测试流媒体解锁"
    echo " ------------------------------------"	
	echo " 20. vps三网回程路线显示"
    echo " 21. 查看服务器路由追踪"
    echo " ------------------------------------"	
    echo " 30. 添加 ll 别名命令"	
    echo " 31. 查看 Reality 配置"
    echo " 32. 安装 NextTrace 路由追踪工具"
    echo " ------------------------------------"	
    echo " 0.  退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    installReality
    ;;
    2)
    installHysteria2
    ;;
    3)
    useRSAandDisablePassword
    ;;
	4)
    disableNzaSSh
    ;;
	5)
	configure_network
	;;
	6)
	install3xui
	;;
    7)
    echo "请输入 SWAP 大小（单位：GB，默认为 2）:"
    read -r swap_size
    if [ -z "$swap_size" ]; then
        configure_swap
    else
        configure_swap "$swap_size"
    fi
    ;;
    8)
    installShadowsocks
    ;;
    11)
    unInstallReality
    ;;	
    12)
    unInstallHysteria2
    ;;
    13)
    checkNetworkQuality
    ;;
    14)
    checkStreamingUnlock
    ;;
    20)
    retRouting
    ;;	
    21)
    runBestTrace
    ;;
    30)
    setLlAlias
    ;;
    31)
    viewRealityConfig
    ;;
    32)
    installNextTrace
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    echo "请输入正确数字"
    sleep 2s
    runmenu
    ;;
    esac
}

timedatectl set-timezone Asia/Shanghai

runmenu
