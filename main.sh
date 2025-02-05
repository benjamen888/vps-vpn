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

runmenu(){
    clear
    echo " ================================================== "
    echo " 介绍：一键安装 Reality和hy2代理    "
    echo " 系统：Ubuntu、Debian、CentOS                        "
    echo " ================================================== "
    echo " 1. 安装 Reality"
    echo " 2. 安装 Hysteria2"
    echo " 3. 关闭密码登陆，启用密钥登陆"
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
