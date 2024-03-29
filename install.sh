#!/bin/sh

UUID=$(cat /proc/sys/kernel/random/uuid)
domain=""
key=`head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 32`
run=false
email="misakanetwork2018@gmail.com"
installcaddy=false

while getopts "d:k:e:rc" arg
do
    case $arg in
        d)
            domain=$OPTARG
            #echo "You set Domain is $domain"
            ;;
        k)
            key=$OPTARG
            #echo "You set Key is $key"
            ;;
        e)
            email=$OPTARG
            ;;
        c)
            installcaddy=true
            ;;
        r)
            run=true
            ;;
        ?)  
            echo "Unkonw argument, skip"
            exit 1
        ;;
    esac
done

function Get_Dist_Name()
{
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt'
    else
        DISTRO='unknow'
    fi
}

function instdpec()
{
    if [ "$1" == "CentOS" ] || [ "$1" == "CentOS7" ];then
        if [ "$installcaddy" == "true" ]; then
        SYSTEM_VER=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
        # 兼容centos8
        if [[ $SYSTEM_VER -ge 8 ]]; then
            dnf -y install 'dnf-command(copr)'
            dnf -y copr enable @caddy/caddy
        else 
            yum -y install yum-plugin-copr
            yum -y copr enable @caddy/caddy
        fi
        fi
        $PM -y install wget curl jq
    elif [ "$1" == "Debian" ] || [ "$1" == "Raspbian" ] || [ "$1" == "Ubuntu" ];then
        if [ "$installcaddy" == "true" ]; then
        echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" \
            | tee -a /etc/apt/sources.list.d/caddy-fury.list
        fi
        $PM update
        $PM -y install wget curl jq
    else
        echo "The shell can be just supported to install v2ray on Centos, Ubuntu and Debian."
        exit 1
    fi
}

root_need() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root!" 1>&2
        exit 1
    fi
}

root_need

Get_Dist_Name
echo "Your OS is $DISTRO"
instdpec $DISTRO

v2ray_proxy_url=`curl -s https://api.github.com/repos/misakanetwork2018/v2ray-api/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url"`
if [ ! -n "$v2ray_proxy_url" ]; then
echo "Get V2ray Api Download URL Failed. Please try again."
exit;
fi

echo "1. Install V2Ray by official shell script"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
if [ $? -ne 0 ]; then
    echo "Failed to install V2Ray. Please try again later."
    exit 1
fi

echo "2. Setting V2Ray to vmess+ws+Caddy"
#Need create dir
mkdir /etc/v2ray
#Modify V2Ray Service
sed -i 's#/usr/local/etc/v2ray/config.json#/etc/v2ray/config.json#' /etc/systemd/system/v2ray.service
sed -i 's#/usr/local/etc/v2ray/config.json#/etc/v2ray/config.json#' /etc/systemd/system/v2ray.service.d/10-donot_touch_single_conf.conf
#Modify V2Ray Config
cat > /etc/v2ray/config.json <<EOF
{
    "stats": {},    
    "api": {
        "services": [
            "HandlerService",
            "LoggerService",
            "StatsService"
        ],
        "tag": "api"
    },
    "policy": {
        "levels": {
            "0": {
                "statsUserUplink": true,
                "statsUserDownlink": true
            },
            "1": {
                "statsUserUplink": false,
                "statsUserDownlink": true
            },
            "2": {
                "statsUserUplink": true,
                "statsUserDownlink": false
            },
            "3": {
                "statsUserUplink": false,
                "statsUserDownlink": false
            }
        },
        "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true
        }
    },
    "inbound": {
        "port": 10000,
        "listen":"127.0.0.1",
        "protocol": "vmess",
        "settings": {
            "clients": [
                {
                    "alterId": 64,
                    "id": "${UUID}",
                    "level": 0,
                    "email": "admin@msknw.club"
                }
            ]
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {
                "path": "/misaka_network"
            }
        },
        "tag": "proxy"
    },
    "inboundDetour": [
        {
            "listen": "127.0.0.1",
            "port": 8848,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1"
            },
            "tag": "api"
        }
    ],
    "log": {
        "loglevel": "debug"
    },
    "outbound": {
        "protocol": "freedom",
        "settings": {}
    },
    "routing": {
        "settings": {
            "rules": [
                {
                    "inboundTag": [
                        "api"
                    ],
                    "outboundTag": "api",
                    "type": "field"
                }
            ]
        },
        "strategy": "rules"
    }
}
EOF
if [ "$installcaddy" == "true" ]; then
#Install Caddy v2
$PM -y install caddy
if [ $? -ne 0 ]; then
    echo "Failed to install Caddy. Please try again later."
    exit 1
fi
fi

echo "3. Install v2ray_proxy"
wget --no-check-certificate -O /usr/bin/v2ray_proxy $v2ray_proxy_url
chmod a+x /usr/bin/v2ray_proxy
#Config
cat > /etc/v2ray/api_config.json <<EOF
{
    "key": "${key}",
    "address": "127.0.0.1:8080"
}
EOF
#Set Caddy Proxy
cat > /etc/caddy/Caddyfile <<EOF
${domain}
{
  tls ${email}
  @websockets {
    header Connection Upgrade
    header Upgrade websocket
  }
  handle /misaka_network* {
    reverse_proxy @websockets localhost:10000
  }
  handle_path /api/* {
    reverse_proxy localhost:8080
  }
  handle {
    respond "Access denied" 403 {
      close
    }
  }
}

EOF
cat > /etc/systemd/system/v2ray-proxy.service <<EOF
[Unit]
Description=V2Ray HTTP API WEB Proxy
After=network.target v2ray.service
Wants=network.target v2ray.service

[Service]
Environment='GIN_MODE=release'
Restart=on-failure
Type=simple
PIDFile=/run/v2ray_proxy.pid
ExecStart=/usr/bin/v2ray_proxy

[Install]
WantedBy=multi-user.target
EOF

echo "4. Run and test"
systemctl daemon-reload
systemctl enable v2ray.service
if [ "$installcaddy" == "true" ]; then
systemctl enable caddy.service
fi
systemctl enable v2ray-proxy.service

# If run
if [ "$run" == "true" ]
then
systemctl start v2ray.service
systemctl start v2ray-proxy.service
if [ "$installcaddy" == "true" ]; then
systemctl restart caddy.service
fi
fi

# Disable and stop firewalld
if [ "$1" == "CentOS" ] || [ "$1" == "CentOS7" ];then
service iptables stop
chkconfig iptables off
systemctl disable firewalld
systemctl stop firewalld
fi

#Finish
IP=`curl ifconfig.me`

vmess_json=`cat <<EOF
{
"v": "2",
"ps": "",
"add": "${domain}",
"port": "443",
"id": "${UUID}",
"aid": "0",
"net": "ws",
"type": "none",
"host": "",
"path": "/misaka_network",
"tls": "tls"
}
EOF`
vmess_base64=$( base64 -w 0 <<< $vmess_json)

link="vmess://$vmess_base64"

cat <<EOF

Final - Everything is OK!

-----------------------------
Server Info
-----------------------------
IP(Internet): ${IP}
V2Ray Domain: ${domain}
Port: 443
Default UUID: ${UUID}
AlterID: 0

streamSettings:
    network: ws
    security: tls
    wsSettings:
        path: /misaka_network
        
vmess link: ${link}

API URL: https://${domain}/api
API Key: ${key}

-----------------------------
Usage
-----------------------------
start api: systemctl start v2ray-proxy
stop api:  systemctl stop v2ray-proxy
-----------------------------
Enjoy your day!
EOF

