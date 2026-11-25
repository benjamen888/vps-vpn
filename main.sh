#!/usr/bin/env bash

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

# 地区与 SNI 的唯一映射；禁止用其他地区的模板值代替。
realityRegion() {
    case "$1" in
        1|sg|新加坡) printf '%s\n' 'sg www.stb.gov.sg' ;;
        2|hk|香港)   printf '%s\n' 'hk www.gov.hk' ;;
        3|jp|日本)   printf '%s\n' 'jp jp.trip.com' ;;
        4|tw|台湾)   printf '%s\n' 'tw tw.trip.com' ;;
        5|us|美国)   printf '%s\n' 'us www.ucdavis.edu' ;;
        *) echo "错误: 地区不能为空或未知，请用 sg / hk / jp / tw / us 或对应中文名" >&2; return 1 ;;
    esac
}

installReality(){
    local country_choice country website resolved
    echo "--------------------------------------------------"
    echo "请选择 Reality 配置的目标网站:"
    echo "1. sg (新加坡)"
    echo "2. hk (香港)"
    echo "3. jp (日本)"
    echo "4. tw (台湾)"
    echo "5. us (美国)"
    read -r -p "请输入数字、地区代码或中文名：" country_choice || return 1
    resolved=$(realityRegion "$country_choice") || return 1
    read -r country website <<< "$resolved"

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

# ==================== VLESS/REALITY 节点管理（菜单 9 / 10） ====================
# 设计说明：
#   本机 xray 用的是「dokodemo-door 公网端口 -> 127.0.0.1 本地 vless/REALITY 端口」结构。
#   新增一个节点 = 追加一对 inbound（公网 dokodemo + 本地 vless）+ 两条路由规则。
#   UUID / X25519 密钥对 / 空闲端口自动生成，新节点 shortId 固定为 88。
#   列表功能从私钥现场反算公钥，不额外保存密钥，避免链接与配置不一致。
#   新版链接只带 sni，不带 peer，显示名为 名称-公网端口。
#   配置版本低于脚本或未登记时，用本次完整新增清单替换所有旧 VLESS/REALITY 节点。
# 可用环境变量覆盖（方便测试/迁移）：
#   XRAY_BIN / XRAY_CONFIG / XRAY_SERVER_IP / XRAY_VLESS_FILE / XRAY_CLASH_FILE
#   XRAY_NO_RESTART=1  只生成并校验候选配置，不写入配置或版本，不重启 xray
XRAY_NODE_CONFIG_VERSION=v1.0.0
if [ -z "$XRAY_BIN" ]; then XRAY_BIN=/usr/local/bin/xray; fi
if [ -z "$XRAY_CONFIG" ]; then XRAY_CONFIG=/usr/local/etc/xray/config.json; fi
if [ "$XRAY_CONFIG" = /usr/local/etc/xray/config.json ]; then
    XRAY_VERSION_FILE=/usr/local/etc/xray/.main-sh-config-version
else
    XRAY_VERSION_FILE="$XRAY_CONFIG.version"
fi
if [ -z "$XRAY_SERVER_IP" ]; then XRAY_SERVER_IP=""; fi
if [ -z "$XRAY_VLESS_FILE" ]; then XRAY_VLESS_FILE=/root/vless-nodes.txt; fi
if [ -z "$XRAY_CLASH_FILE" ]; then XRAY_CLASH_FILE=/root/clash-proxies.yaml; fi
if [ -z "$XRAY_NO_RESTART" ]; then XRAY_NO_RESTART=0; fi

# $1=action(gen|list|del)  $2=新增批次或删除目标  $3=候选配置输出路径
_xrayTool() {
XRAY_BIN="$XRAY_BIN" XRAY_CONFIG="$XRAY_CONFIG" XRAY_OUT_CONFIG="$3" \
XRAY_ACTION="$1" XRAY_SELECTION="$2" XRAY_SERVER_IP="$XRAY_SERVER_IP" \
XRAY_VLESS_FILE="$XRAY_VLESS_FILE" XRAY_CLASH_FILE="$XRAY_CLASH_FILE" \
XRAY_RECORDED_VERSION="$XRAY_RECORDED_VERSION" XRAY_NODE_CONFIG_VERSION="$XRAY_NODE_CONFIG_VERSION" \
PYTHONIOENCODING=utf-8 python3 - <<'PY'
import datetime
import json
import os
import ipaddress
import re
import socket
import subprocess
import sys
import urllib.parse
import uuid

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

BIN   = os.environ['XRAY_BIN']
CFG   = os.environ['XRAY_CONFIG']
OUT   = os.environ.get('XRAY_OUT_CONFIG', '')
ACT   = os.environ['XRAY_ACTION']
SELECTION = os.environ.get('XRAY_SELECTION', '')
SRVIP = os.environ.get('XRAY_SERVER_IP', '')
VFILE = os.environ['XRAY_VLESS_FILE']
CFILE = os.environ['XRAY_CLASH_FILE']
NOW   = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')

# 新节点 tag 与线上 v1.0.0 一致。
SHARE_TAG_PREFIX = 'vless-share:'
NEW_SHORT_ID = '88'
CURRENT_VERSION = os.environ['XRAY_NODE_CONFIG_VERSION']
RECORDED_VERSION = os.environ.get('XRAY_RECORDED_VERSION', '')
CURRENT_FORMAT = RECORDED_VERSION == CURRENT_VERSION


def die(msg):
    print('错误: ' + msg, file=sys.stderr)
    sys.exit(1)


def listening_ports():
    """从 /proc/net/tcp* 读取处于 LISTEN(0A) 的端口，不依赖 ss"""
    ports = set()
    for path in ('/proc/net/tcp', '/proc/net/tcp6'):
        try:
            with open(path) as f:
                for line in f.read().splitlines()[1:]:
                    p = line.split()
                    if len(p) > 3 and p[3] == '0A':
                        ports.add(int(p[1].split(':')[1], 16))
        except OSError:
            pass
    return ports


def port_busy(port, used):
    if port in used:
        return True
    s = socket.socket()
    try:
        s.bind(('0.0.0.0', port))
        return False
    except OSError:
        return True
    finally:
        s.close()


def server_ip():
    if SRVIP:
        return SRVIP
    try:
        out = subprocess.check_output(['ip', '-4', 'route', 'get', '1.1.1.1'],
                                      text=True, stderr=subprocess.DEVNULL)
        m = re.search(r'\bsrc\s+(\d+\.\d+\.\d+\.\d+)', out)
        if m:
            return m.group(1)
    except Exception:
        pass
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]
    finally:
        s.close()


def keypair(private=''):
    """生成 X25519 密钥对；传入 private 时反算公钥。

    xray x25519 的输出标签随内核版本变化：
      1.8.x : "Private key:" / "Public key:"
      26.x  : "PrivateKey:" / "Password (PublicKey):" / "Hash32:"
    两种都解析，避免跨版本部署时生成节点失败。
    """
    cmd = [BIN, 'x25519']
    if private:
        cmd += ['-i', private]
    out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
    m_priv = re.search(r'(?:Private [Kk]ey|PrivateKey):\s*(\S+)', out)
    m_pub = re.search(r'(?:Public [Kk]ey|Password \(PublicKey\)|PublicKey):\s*(\S+)', out)
    priv = m_priv.group(1) if m_priv else ''
    pub = m_pub.group(1) if m_pub else ''
    if private:
        if not pub:
            die('无法从私钥反算公钥: ' + out.strip())
        return pub
    if not priv or not pub:
        die('xray x25519 输出解析失败: ' + out.strip())
    return priv, pub


def load_cfg(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def version_tuple(version):
    match = re.fullmatch(r'v([0-9]+)\.([0-9]+)\.([0-9]+)', version)
    return tuple(map(int, match.groups())) if match else None


def save_candidate(cfg):
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=4, ensure_ascii=False)
        f.write('\n')


def is_reality(inbound):
    return (inbound.get('protocol') == 'vless' and
            inbound.get('streamSettings', {}).get('security') == 'reality')


def is_loopback(address):
    if address == 'localhost':
        return True
    try:
        return ipaddress.ip_address(address or '').is_loopback
    except ValueError:
        return False


def forwards_to(inbound, vless):
    settings = inbound.get('settings', {})
    address = settings.get('address')
    listen = vless.get('listen')
    return (inbound.get('protocol') in ('dokodemo-door', 'tunnel') and
            not settings.get('followRedirect') and is_loopback(address) and
            (listen in (None, '', '0.0.0.0', '::', 'localhost', address)
             or (address == 'localhost' and is_loopback(listen))) and
            str(settings.get('port', '')) == str(vless.get('port', '')))


def remove_nodes(cfg, targets):
    before = cfg.get('inbounds', [])
    target_ids = {id(i) for i in targets}
    drop = [i for i in before if id(i) in target_ids or
            any(forwards_to(i, v) for v in targets)]
    tags = {i['tag'] for i in drop if i.get('tag')}
    drop_ids = {id(i) for i in drop}
    kept = [i for i in before if id(i) not in drop_ids]
    if tags.intersection(i.get('tag') for i in kept):
        die('待移除节点的 tag 被其他入站共用，已取消')
    cfg['inbounds'] = kept
    for rule in cfg.get('routing', {}).get('rules', []):
        if 'inboundTag' in rule and not isinstance(rule['inboundTag'], list):
            die('路由 inboundTag 不是列表，无法安全清理')
    rules = cfg.get('routing', {}).get('rules', [])
    clean = []
    for rule in rules:
        old = rule.get('inboundTag', [])
        rest = [tag for tag in old if tag not in tags]
        if len(rest) == len(old):
            clean.append(rule)
        elif rest:
            clean.append(dict(rule, inboundTag=rest))
    if 'rules' in cfg.get('routing', {}):
        cfg['routing']['rules'] = clean
    return len(drop)


def configured_ports(inbounds):
    ports = set()
    for inbound in inbounds:
        port = inbound.get('port')
        if port is None:
            continue
        for value in str(port).split(','):
            m = re.fullmatch(r'\s*([0-9]{1,5})(?:-([0-9]{1,5}))?\s*', value)
            if not m:
                die('无法安全识别已有入站端口: ' + str(port))
            first = int(m[1])
            last = int(m[2] or m[1])
            if not 0 <= first <= last <= 65535:
                die('已有入站端口超出范围: ' + str(port))
            ports.update(range(first, last + 1))
    return ports


def ensure_route_outbounds(cfg):
    outbounds = cfg.setdefault('outbounds', [])
    for tag, protocol in [('direct', 'freedom'), ('block', 'blackhole')]:
        matches = [o for o in outbounds if o.get('tag') == tag]
        if not matches:
            outbounds.append({'tag': tag, 'protocol': protocol})
        elif len(matches) != 1 or matches[0].get('protocol') != protocol:
            die('已有出站 tag 与节点路由冲突: ' + tag)


def vless_link(n):
    """以节点配置中的 shortId 导出，旧节点沿用原查询参数和显示名。"""
    q = [('encryption', 'none'), ('flow', n['flow']), ('security', 'reality'),
         ('sni', n['sni'])]
    display_name = n['name']
    if n.get('new_share_format'):
        display_name = '{}-{}'.format(n['name'], n['port'])
    else:
        q.append(('peer', n['sni']))
    q += [('fp', 'chrome'), ('pbk', n['pbk']), ('sid', n['sid']),
          ('type', 'tcp'), ('headerType', 'none')]
    return 'vless://{}@{}:{}?{}#{}'.format(
        n['uuid'], n['ip'], n['port'], urllib.parse.urlencode(q),
        urllib.parse.quote(display_name, safe='-_.~'))


def clash_block(nodes):
    """生成 Clash Verge / Mihomo 的 proxies: 片段"""
    lines = ['proxies:']
    for n in nodes:
        lines += [
            '  - name: "{}"'.format(n['name']),
            '    type: vless',
            '    server: {}'.format(n['ip']),
            '    port: {}'.format(n['port']),
            '    uuid: {}'.format(n['uuid']),
            '    network: tcp',
            '    udp: false',
            '    tls: true',
            '    flow: {}'.format(n['flow']),
            '    servername: {}'.format(n['sni']),
            '    client-fingerprint: chrome',
            '    reality-opts:',
            '      public-key: "{}"'.format(n['pbk']),
            '      short-id: "{}"'.format(n['sid']),
        ]
    return '\n'.join(lines)


def collect(cfg, ip):
    """扫描配置里全部 vless/REALITY 节点，判断可用性"""
    listening = listening_ports()
    try:
        active = subprocess.check_output(['systemctl', 'is-active', 'xray'],
                                         text=True, stderr=subprocess.DEVNULL).strip() == 'active'
    except Exception:
        active = False
    nodes = []
    for v in cfg.get('inbounds', []):
        if v.get('protocol') != 'vless':
            continue
        rs = v.get('streamSettings', {})
        if rs.get('security') != 'reality':
            continue
        rl = rs.get('realitySettings', {})
        local_port = int(v.get('port', 0))
        public_port = 0 if is_loopback(v.get('listen')) else local_port
        for d in cfg.get('inbounds', []):
            if forwards_to(d, v):
                public_port = int(d.get('port', 0))
                break
        tag = v.get('tag', '')
        uses_share_tag = tag.startswith(SHARE_TAG_PREFIX)
        new_share_format = CURRENT_FORMAT or uses_share_tag
        if uses_share_tag:
            name = tag[len(SHARE_TAG_PREFIX):]
        elif tag.startswith('vless-'):
            name = tag[len('vless-'):]
        else:
            name = 'reality-{}'.format(public_port or local_port)
        clients = v.get('settings', {}).get('clients', [{}])
        priv = rl.get('privateKey', '')
        pbk = keypair(priv) if priv else ''
        n = {
            'name': name, 'ip': ip, 'port': public_port,
            'new_share_format': new_share_format,
            'uuid': clients[0].get('id', ''),
            'flow': clients[0].get('flow', 'xtls-rprx-vision'),
            'sni': (rl.get('serverNames') or [''])[0],
            'pbk': pbk, 'sid': (rl.get('shortIds') or [''])[0],
            'local': local_port,
        }
        n['ok'] = bool(public_port and public_port in listening and active and pbk)
        nodes.append(n)
    return nodes, active


def write_files(targets, ip):
    try:
        with open(VFILE, 'w', encoding='utf-8') as f:
            f.write('# main.sh 生成 ' + NOW + '  服务器 ' + ip + '\n')
            for n in targets:
                f.write(vless_link(n) + '\n')
        with open(CFILE, 'w', encoding='utf-8') as f:
            f.write('# main.sh 生成 ' + NOW + '  服务器 ' + ip + '\n')
            f.write((clash_block(targets) if targets else 'proxies: []') + '\n')
        os.chmod(VFILE, 0o600)
        os.chmod(CFILE, 0o600)
    except OSError as e:
        die('写入清单文件失败: ' + str(e))


def do_list(cfg, ip):
    nodes, active = collect(cfg, ip)
    if not nodes:
        print('当前没有 vless/REALITY 节点')
        write_files([], ip)
        print('已清空清单: ' + VFILE + ' / ' + CFILE)
        return
    ok = [n for n in nodes if n['ok']]
    print('==================================================')
    print(' 本机 VLESS/REALITY 节点清单   ' + NOW)
    print(' 服务器: ' + ip + '   xray: ' + ('运行中' if active else '未运行'))
    print(' 节点: ' + str(len(nodes)) + ' 个，可用: ' + str(len(ok)) + ' 个')
    print('==================================================')
    print('')
    print('----- VLESS 链接（#序号 可用于删除）-----')
    for i, n in enumerate(nodes, 1):
        print('#' + str(i) + ' [' + ('可用' if n['ok'] else '不可用') + '] ' +
              n['name'] + '   公网端口 ' + str(n['port']) + '   本地端口 ' + str(n['local']))
        print(vless_link(n))
    print('')
    print('----- Clash / Mihomo 片段（粘贴到配置文件的 proxies: 处）-----')
    print(clash_block(ok if ok else nodes))
    print('')
    targets = ok if ok else nodes
    if not ok:
        print('提示: 当前没有「可用」节点，文件里写入的是全部节点，请先检查 xray 与端口监听。')
    write_files(targets, ip)
    print('已保存: ' + VFILE)
    print('已保存: ' + CFILE)


def do_gen(cfg, ip):
    if not OUT:
        die('未指定新配置输出路径')
    before = cfg.get('inbounds', [])
    old_nodes = [i for i in before if is_reality(i)]
    used = configured_ports(before) | listening_ports()
    names = set()
    manual_ports = set()
    requests = []
    for line in SELECTION.splitlines():
        name, region, sni, port = line.split(':')
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,32}', name):
            die('节点名称只能包含字母/数字/-/_，长度 1~32')
        if name in names:
            die('本次节点名称重复: ' + name)
        names.add(name)
        if port:
            if not re.fullmatch(r'[0-9]{4,5}', port) or not 1024 <= int(port) <= 65535:
                die('端口必须是 1024~65535 的数字')
            port = int(port)
            if port in manual_ports or port_busy(port, used):
                die('端口重复或已被占用: ' + str(port))
            manual_ports.add(port)
        requests.append((name, region, sni, port))
    if not requests:
        die('请至少指定一个新节点及其地区')
    used.update(manual_ports)

    # 替换只发生在候选配置中；原配置和旧监听在提交前保持不动。
    if not CURRENT_FORMAT:
        remove_nodes(cfg, old_nodes)
        print('候选配置将替换 ' + str(len(old_nodes)) + ' 个旧 VLESS/REALITY 节点。')
    ensure_route_outbounds(cfg)
    inbounds = cfg.setdefault('inbounds', [])
    new_rules = []
    next_public = 20000
    next_local = 58890
    for name, region, sni, public_port in requests:
        d_tag = 'dokodemo-' + name
        v_tag = SHARE_TAG_PREFIX + name
        if any(i.get('tag') in (d_tag, v_tag, 'vless-' + name) for i in inbounds):
            die('节点名称已存在: ' + name)
        if not public_port:
            while next_public <= 59999 and port_busy(next_public, used):
                next_public += 1
            if next_public > 59999:
                die('20000~59999 没有空闲公网端口')
            public_port = next_public
            next_public += 1
            used.add(public_port)
        while next_local <= 65535 and port_busy(next_local, used):
            next_local += 1
        if next_local > 65535:
            die('找不到可用的本地回环端口')
        local_port = next_local
        next_local += 1
        used.add(local_port)

        private, public = keypair()
        uid = str(uuid.uuid4())
        flow = 'xtls-rprx-vision'
        inbounds.extend([
            {'tag': d_tag, 'port': public_port, 'protocol': 'dokodemo-door',
             'settings': {'address': '127.0.0.1', 'port': local_port, 'network': 'tcp'},
             'sniffing': {'enabled': True, 'destOverride': ['tls'], 'routeOnly': True}},
            {'tag': v_tag, 'listen': '127.0.0.1', 'port': local_port, 'protocol': 'vless',
             'settings': {'clients': [{'id': uid, 'flow': flow}], 'decryption': 'none'},
             'streamSettings': {'network': 'tcp', 'security': 'reality',
                                'realitySettings': {'dest': sni + ':443', 'xver': 0,
                                                    'serverNames': [sni], 'privateKey': private,
                                                    'minClientVer': '1.0.0',
                                                    'shortIds': [NEW_SHORT_ID]}}},
        ])
        new_rules.extend([
            {'type': 'field', 'inboundTag': [d_tag], 'domain': ['full:' + sni],
             'outboundTag': 'direct'},
            {'type': 'field', 'inboundTag': [d_tag], 'outboundTag': 'block'},
        ])
        n = {'name': name, 'ip': ip, 'port': public_port, 'uuid': uid, 'flow': flow,
             'sni': sni, 'pbk': public, 'sid': NEW_SHORT_ID, 'new_share_format': True}
        print('{} [{}] 公网端口 {} / 本地端口 {}，SNI {}'.format(
            name, region, public_port, local_port, sni))
        print(vless_link(n))

    rules = cfg.setdefault('routing', {}).setdefault('rules', [])
    rules[0:0] = new_rules
    save_candidate(cfg)


def do_del(cfg, ip):
    if not OUT:
        die('未指定新配置输出路径')
    if not CURRENT_FORMAT:
        die('配置版本不一致。请用 gen-batch 指定完整的新节点清单；del 不能触发全量替换')
    nodes, _ = collect(cfg, ip)
    if not nodes:
        die('配置中没有可删除的 VLESS/REALITY 节点')
    key = SELECTION.strip()
    by_index = key.startswith('#')
    if by_index:
        key = key[1:].strip()
    if not key:
        die('请指定节点名称或序号')
    if len(nodes) == 1:
        die('只剩 1 个节点，拒绝删除')
    candidates = [i for i in cfg['inbounds'] if is_reality(i)]
    matches = [] if by_index else [j for j, n in enumerate(nodes) if n['name'] == key]
    if not matches and re.fullmatch(r'[0-9]+', key):
        idx = int(key)
        if not 1 <= idx <= len(nodes):
            die('序号超出范围：1~' + str(len(nodes)))
        matches = [idx - 1]
    if not matches:
        die('找不到名称为 ' + key + ' 的节点')
    if len(matches) != 1:
        die('存在同名节点，请使用非重复的节点名称')
    idx = matches[0]
    removed = remove_nodes(cfg, [candidates[idx]])
    save_candidate(cfg)
    print('已删除节点: {}（移除 {} 个入站）'.format(nodes[idx]['name'], removed))

if ACT in ('gen', 'del'):
    recorded = version_tuple(RECORDED_VERSION)
    if recorded is not None and recorded > version_tuple(CURRENT_VERSION):
        die('已登记配置版本 ' + RECORDED_VERSION + ' 高于脚本版本 ' + CURRENT_VERSION + '，拒绝覆盖')

cfg = load_cfg(CFG)
ip = server_ip()
if ACT == 'gen':
    do_gen(cfg, ip)
elif ACT == 'list':
    do_list(cfg, ip)
elif ACT == 'del':
    do_del(cfg, ip)
else:
    die('未知操作: ' + ACT)
PY
}

# 单节点：gen <名称> <地区> [端口]；批量：gen-batch <名称:地区[:端口]>...
xrayAddNode() {
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        echo "用法: bash main.sh gen <名称> <地区> [端口]" >&2
        return 1
    fi
    xrayAddBatch "$1:$2:${3:-}"
}

xrayAddBatch() {
    local spec name region port resolved code sni payload=''
    if [ ! -x "$XRAY_BIN" ]; then echo "错误: 找不到 $XRAY_BIN"; return 1; fi
    if [ ! -f "$XRAY_CONFIG" ]; then echo "错误: 找不到配置 $XRAY_CONFIG"; return 1; fi
    if [ "$#" -eq 0 ]; then
        echo "用法: bash main.sh gen-batch <名称:地区[:端口]> ..." >&2
        return 1
    fi
    for spec in "$@"; do
        if ! [[ "$spec" =~ ^([A-Za-z0-9_-]{1,32}):([^:[:space:]]+)(:([0-9]*))?$ ]]; then
            echo "错误: 请按 名称:地区[:端口] 指定每个节点" >&2
            return 1
        fi
        name=${BASH_REMATCH[1]}
        region=${BASH_REMATCH[2]}
        port=${BASH_REMATCH[4]}
        if [ -n "$port" ] && ! [[ "$port" =~ ^[0-9]{4,5}$ ]]; then
            echo "错误: 端口请填 1024~65535 的数字" >&2
            return 1
        fi
        resolved=$(realityRegion "$region") || return 1
        read -r code sni <<< "$resolved"
        payload+="$name:$code:$sni:$port"$'\n'
    done
    _xrayChangeNode gen "$payload"
}

xrayAddFromMenu() {
    local -a nodes
    echo "输入一个或多个 名称:地区[:端口]，用空格分隔。"
    echo "例如：zgous1:us zgous2:美国 zgous3:us:20005"
    echo "版本缺失或落后时，旧节点会被整体替换，请一次输入全部新节点。"
    read -r -a nodes || return 1
    if [ "${#nodes[@]}" -eq 0 ]; then echo "已取消"; return 0; fi
    xrayAddBatch "${nodes[@]}"
}

# 锁在读取版本/配置之前获取，防止并发增删用旧副本覆盖新配置。
_xrayReadConfigVersion() {
    XRAY_RECORDED_VERSION=
    if [ -f "$XRAY_VERSION_FILE" ]; then
        XRAY_RECORDED_VERSION=$(cat -- "$XRAY_VERSION_FILE") || return 1
    elif [ -e "$XRAY_VERSION_FILE" ] || [ -L "$XRAY_VERSION_FILE" ]; then
        echo "错误: 无法读取配置版本: $XRAY_VERSION_FILE" >&2
        return 1
    fi
}

xrayListNodes() (
    if [ ! -f "$XRAY_CONFIG" ]; then echo "错误: 找不到配置 $XRAY_CONFIG"; return 1; fi
    umask 077
    exec 9>>"$XRAY_CONFIG.lock" || return 1
    flock -x 9 || return 1
    _xrayReadConfigVersion || return 1
    _xrayTool list "" ""
)

_xrayChangeNode() (
    local action="$1" selection="$2" tmp='' staged_version='' out
    umask 077
    exec 9>>"$XRAY_CONFIG.lock" || return 1
    flock -x 9 || return 1
    _xrayReadConfigVersion || return 1

    # 退出时清理尚未提交的候选文件。
    trap 'if [ -n "$tmp" ]; then rm -f -- "$tmp"; fi; if [ -n "$staged_version" ]; then rm -f -- "$staged_version"; fi' EXIT
    tmp=$(mktemp --suffix=.json "$XRAY_CONFIG.tmp.XXXXXX") || return 1
    if ! out=$(_xrayTool "$action" "$selection" "$tmp" 2>&1); then
        echo "$out"
        echo "操作失败，原配置和版本未改动"; return 1
    fi
    if [ "$XRAY_RECORDED_VERSION" != "$XRAY_NODE_CONFIG_VERSION" ]; then
        printf '配置版本 %s → %s：全部旧 VLESS/REALITY 节点将被本次新增清单替换；旧链接失效。\n' \
            "${XRAY_RECORDED_VERSION:-未登记}" "$XRAY_NODE_CONFIG_VERSION"
        if [ "$XRAY_NO_RESTART" != "1" ]; then
            staged_version=$(mktemp "$XRAY_VERSION_FILE.tmp.XXXXXX") || return 1
            printf '%s\n' "$XRAY_NODE_CONFIG_VERSION" > "$staged_version" || return 1
        fi
    fi

    _xrayApplyConfig "$tmp" "$staged_version" || return 1
    if [ "$XRAY_NO_RESTART" = "1" ]; then return 0; fi
    if [ "$action" = gen ]; then
        echo "===== 新节点已写入配置 ====="
        printf '%s\n' "$out"
        echo "注意: 云厂商安全组/外部防火墙需放行该公网端口。"
    else
        printf '%s\n' "$out"
    fi

    if [ -n "$staged_version" ]; then
        XRAY_RECORDED_VERSION="$XRAY_NODE_CONFIG_VERSION"
        echo "配置版本: $XRAY_NODE_CONFIG_VERSION ($XRAY_VERSION_FILE)"
    fi
    echo "----- 刷新后的完整节点清单 -----"
    _xrayTool list "" "" || echo "警告: 配置已生效，但刷新清单失败；可单独运行 list 重试。"
)

# 校验候选 -> 备份旧配置 -> 应用并检查服务 -> 最后提交版本；任何一步失败都不推进版本。
_xrayApplyConfig() {
    local tmp="$1" staged_version="$2" bak perms
    if ! "$XRAY_BIN" run -test -format=json -c "$tmp"; then
        echo "错误: 新配置未通过 Xray 校验，原配置和版本未改动"
        return 1
    fi
    if [ "$XRAY_NO_RESTART" = "1" ]; then
        echo "预检通过：未写入配置或版本，未重启 Xray"
        return 0
    fi

    perms=$(stat -c %a -- "$XRAY_CONFIG") || return 1
    bak=$(mktemp "$XRAY_CONFIG.bak.$(date +%Y%m%d%H%M%S).XXXXXX") || return 1
    if ! cp -a -- "$XRAY_CONFIG" "$bak" || ! chmod 600 -- "$bak"; then
        echo "错误: 备份失败，原配置和版本未改动"
        return 1
    fi
    if [ -f "$XRAY_VERSION_FILE" ] && ! cat -- "$XRAY_VERSION_FILE" > "$bak.version"; then
        echo "错误: 备份版本失败，原配置和版本未改动"
        return 1
    fi
    if ! chown --reference="$bak" -- "$tmp" ||
       ! chmod "$perms" -- "$tmp" ||
       ! mv -fT -- "$tmp" "$XRAY_CONFIG"; then
        echo "错误: 应用配置失败，版本未改动（备份: $bak）"
        return 1
    fi

    if systemctl restart xray && sleep 1 && systemctl is-active --quiet xray; then
        if [ -z "$staged_version" ] || mv -fT -- "$staged_version" "$XRAY_VERSION_FILE"; then
            echo "配置备份: $bak"
            return 0
        fi
        echo "错误: 写入配置版本失败，正在回滚"
    else
        echo "错误: Xray 启动检查失败，正在回滚"
    fi

    if cp -a -- "$bak" "$tmp" &&
       chmod "$perms" -- "$tmp" &&
       mv -fT -- "$tmp" "$XRAY_CONFIG" &&
       systemctl restart xray && systemctl is-active --quiet xray; then
        echo "已回滚旧配置，版本未改动（备份: $bak）"
    else
        echo "错误: 自动回滚未完成，请从 $bak 恢复并检查 Xray 服务" >&2
    fi
    return 1
}

# 删除节点：bash main.sh del <名称|序号>；交互模式下先列出带序号的节点并二次确认
xrayDeleteNode() {
    local target="$1" ans
    if [ "$EUID" -ne 0 ]; then echo "错误: 必须用 root 运行"; return 1; fi
    if [ ! -x "$XRAY_BIN" ]; then echo "错误: 找不到 $XRAY_BIN"; return 1; fi
    if [ ! -f "$XRAY_CONFIG" ]; then echo "错误: 找不到配置 $XRAY_CONFIG"; return 1; fi

    if [ -z "$target" ]; then
        echo "--------------------------------------------------"
        echo " 删除 VLESS/REALITY 节点"
        echo " 可输入节点名称，或 list 输出里的 #序号"
        echo "--------------------------------------------------"
        xrayListNodes || return 1
        echo "--------------------------------------------------"
        read -r -p "请输入节点名称或 #序号(例如 tvbox 或 2，直接回车取消): " target
        if [ -z "$target" ]; then echo "已取消"; return 0; fi
        read -r -p "确认删除 [$target] 并重启 xray? [y/N]: " ans
        if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then echo "已取消"; return 0; fi
    fi

    _xrayChangeNode del "$target"
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
    echo " 9. 新增／批量替换 VLESS/REALITY 节点（输入名称和地区）"
    echo " 10. 列出全部 VLESS 节点（vless 链接 + Clash 格式，带 #序号）"
    echo " ------------------------------------"
    echo " 11. 卸载 Reality"
    echo " 12. 卸载 Hysteria2"
    echo " 13. 测试网络质量"
    echo " 14. 测试流媒体解锁"
    echo " 15. 删除 VLESS 节点（按名称或 #序号）"
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
    9)
    xrayAddFromMenu
    echo "按任意键返回主菜单..."
    read -n 1
    runmenu
    ;;
    10)
    xrayListNodes
    echo "按任意键返回主菜单..."
    read -n 1
    runmenu
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
    15)
    xrayDeleteNode ""
    echo "按任意键返回主菜单..."
    read -n 1
    runmenu
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

# 非交互用法：gen <名称> <地区> [端口] / gen-batch <名称:地区[:端口]>... / list / del
case "$1" in
    gen|add)
        shift
        xrayAddNode "$@"
        ;;
    gen-batch|add-batch)
        shift
        xrayAddBatch "$@"
        ;;
    list|ls)
        xrayListNodes
        ;;
    del|rm|delete)
        xrayDeleteNode "$2"
        ;;
    ""|menu)
        check_and_install_curl
        timedatectl set-timezone Asia/Shanghai
        runmenu
        ;;
    *)
        echo "未知命令: $1（可用：gen / gen-batch / list / del / menu）" >&2
        exit 1
        ;;
esac
