#!/bin/sh

if [[ $EUID -ne 0 ]]; then
    clear
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi


hyPasswd=$(cat /proc/sys/kernel/random/uuid)
getPort=12345
# Function to check if a port is available
check_port() {
  local port=$1
  if (echo > /dev/tcp/127.0.0.1/$port) &>/dev/null; then
    return 1  # Port is in use
  else
    return 0  # Port is available
  fi
}

# Generate a random port and check its availability
while true; do
  getPort=$(shuf -i 10000-20000 -n 1)
  if check_port $port; then
    echo "Available port: $port"
    break
  else
    echo "Port $port is in use, trying another..."
  fi
done



getIP(){
    local serverIP=
    serverIP=$(curl -s -4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    if [[ -z "${serverIP}" ]]; then
        serverIP=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    fi
    echo "${serverIP}"
}

install_hy2(){
    if [ -f "/usr/bin/apt-get" ]; then
        apt-get update -y && apt-get upgrade -y
        apt-get install -y gawk curl
    else
        yum update -y && yum upgrade -y
        yum install -y epel-release
        yum install -y gawk curl
    fi
    bash <(curl -fsSL https://get.hy2.sh/)
    mkdir -p /etc/hysteria/
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500 && chown hysteria /etc/hysteria/server.key && chown hysteria /etc/hysteria/server.crt

cat >/etc/hysteria/config.yaml <<EOF
listen: :$getPort
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $hyPasswd
  
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
quic:
  initStreamReceiveWindow: 26843545 
  maxStreamReceiveWindow: 26843545 
  initConnReceiveWindow: 67108864 
  maxConnReceiveWindow: 67108864 
EOF

systemctl enable hysteria-server.service && systemctl restart hysteria-server.service && systemctl status --no-pager hysteria-server.service
rm -f main.sh hy2.sh

cat >/etc/hysteria/hyclient.json<<EOF
{
===========配置参数=============
代理模式：Hysteria2
地址：$(getIP)
端口：${getPort}
密码：${hyPasswd}
SNI：bing.com
传输协议：tls
跳过证书验证：ture
====================================
hysteria2://$(echo -n "${hyPasswd}@$(getIP):${getPort}/?insecure=1&sni=bing.com#hy2-${getPort}")
}
EOF

    clear
}

client_hy2(){
    hylink=$(echo -n "${hyPasswd}@$(getIP):${getPort}/?insecure=1&sni=bing.com#hy2-${getPort}")

    echo
    echo "安装已经完成"
    echo
    echo "===========Hysteria2配置参数============"
    echo
    echo "地址：$(getIP)"
    echo "端口：${getPort}"
    echo "密码：${hyPasswd}"
    echo "SNI：bing.com"
    echo "传输协议：tls"
    echo "打开跳过证书验证，true"
    echo
    echo "========================================="
    echo "hysteria2://${hylink}"
    echo
}

install_hy2
client_hy2

