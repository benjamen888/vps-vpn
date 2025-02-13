#!/bin/sh

if [[ $EUID -ne 0 ]]; then
    clear
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

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
	wget https://raw.githubusercontent.com/benjamen888/vps-vpn/main/proxytype/reality.sh && bash reality.sh 
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
    echo " ------------------------------------"
    echo " 11. 卸载 Reality"
    echo " 12. 卸载 Hysteria2"
    echo " ------------------------------------"	
	echo " 20. vps三网回程路线显示"
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
    11)
    unInstallReality
    ;;	
    12)
    unInstallHysteria2
    ;;
    20)
    retRouting
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
