#!/bin/sh

if [[ $EUID -ne 0 ]]; then
    clear
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi

v2uuid=$(cat /proc/sys/kernel/random/uuid)

read -t 30 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)：" getPort
if [ -z $getPort ]; then
    getPort=443
fi

getIP(){
    local serverIP=
    serverIP=$(curl -s -4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    if [[ -z "${serverIP}" ]]; then
        serverIP=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    fi
    echo "${serverIP}"
}

install_xray(){
    if [ -f "/usr/bin/apt-get" ]; then
        apt-get update -y && apt-get upgrade -y
        apt-get install -y gawk curl
    else
        yum update -y && yum upgrade -y
        yum install -y epel-release
        yum install -y gawk curl
    fi
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

reconfig(){
    reX25519Key=$(/usr/local/bin/xray x25519)
    rePrivateKey=$(echo "${reX25519Key}" | head -1 | awk '{print $3}')
    rePublicKey=$(echo "${reX25519Key}" | tail -n 1 | awk '{print $3}')

cat >/usr/local/etc/xray/config.json<<EOF
{
    "inbounds": [
        {
            "port": $getPort,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.amazon.com:443",
                    "xver": 0,
                    "serverNames": [
                        "www.amazon.com",
                        "addons.mozilla.org",
                        "www.un.org",
                        "www.tesla.com"
                    ],
                    "privateKey": "$rePrivateKey",
                    "minClientVer": "",
                    "maxClientVer": "",
                    "maxTimeDiff": 0,
                    "shortIds": [
                        "88",
                        "123abc"
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "blocked"
        }
    ]
}
EOF

    systemctl enable xray.service && systemctl restart xray.service
    rm -f main.sh install-release.sh reality.sh

cat >/usr/local/etc/xray/reclient.json<<EOF
{
===========配置参数=============
代理模式：vless
地址：$(getIP)
端口：${getPort}
UUID：${v2uuid}
流控：xtls-rprx-vision
传输协议：tcp
Public key：${rePublicKey}
底层传输：reality
SNI: www.amazon.com
shortIds: 88
====================================
vless://${v2uuid}@$(getIP):${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#reality-${getPort}
====================================
Clash 配置:
{
- name: "reality-${getPort}"
  type: vless
  server: $(getIP)
  port: ${getPort}
  udp: true
  uuid: "${v2uuid}"
  flow: xtls-rprx-vision
  packet-encoding: xudp
  tls: true
  servername: "www.amazon.com"
  alpn:
    - h2
  client-fingerprint: chrome
  skip-cert-verify: true
  reality-opts:
    public-key: "${rePublicKey}"
    short-id: "88"
  network: tcp
  smux:
    enabled: false
}
EOF

    clear
}

client_re(){
    echo
    echo "安装已经完成"
    echo
    echo "===========reality配置参数============"
    echo "代理模式：vless"
    echo "地址：$(getIP)"
    echo "端口：${getPort}"
    echo "UUID：${v2uuid}"
    echo "流控：xtls-rprx-vision"
    echo "传输协议：tcp"
    echo "Public key：${rePublicKey}"
    echo "底层传输：reality"
    echo "SNI: www.amazon.com"
    echo "shortIds: 88"
    echo "===================================="
    echo "vless://${v2uuid}@$(getIP):${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#reality-${getPort}"
    echo "===================================="
    echo "Clash 配置:"
    echo "{
- name: \"reality-${getPort}\"
  type: vless
  server: $(getIP)
  port: ${getPort}
  udp: true
  uuid: \"${v2uuid}\"
  flow: xtls-rprx-vision
  packet-encoding: xudp
  tls: true
  servername: \"www.amazon.com\"
  alpn:
    - h2
  client-fingerprint: chrome
  skip-cert-verify: true
  reality-opts:
    public-key: \"${rePublicKey}\"
    short-id: \"88\"
  network: tcp
  smux:
    enabled: false
}"
    echo
}

install_xray
reconfig
client_re
