#!/bin/sh

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
        $PM -y install wget curl
    elif [ "$1" == "Debian" ] || [ "$1" == "Raspbian" ] || [ "$1" == "Ubuntu" ];then
        $PM update
        $PM -y install wget curl
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

UUID=$(cat /proc/sys/kernel/random/uuid)
v2_domain=""
api_domain=""
v2ray_proxy_url="https://github.com/misakanetwork2018/v2ray_api/releases/download/v0.1/v2ray_proxy"
key=`head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 32`

while getopts "a:v:k:" arg
do
    case $arg in
        a)
            api_domain=$OPTARG
            #echo "You set API Domain is $api_domain"
            ;;
        v)
            v2_domain=$OPTARG
            #echo "You set V2Ray Domain is $v2_domain"
            ;;
        k)
            key=$OPTARG
            #echo "You set Kye is $key"
            ;;
        ?)  
            echo "Unkonw argument, skip"
            exit 1
        ;;
    esac
done

Get_Dist_Name
echo "Your OS is $DISTRO"
instdpec $DISTRO

echo "1. Install V2Ray by official shell script"
bash <(curl -L -s https://install.direct/go.sh)
if [ $? -ne 0 ]; then
    echo "Failed to install V2Ray. Please try again later."
    exit 1
fi

echo "2. Setting V2Ray to vmess+ws+Caddy"
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
#Install Caddy
curl https://getcaddy.com | bash -s personal
if [ $? -ne 0 ]; then
    echo "Failed to install Caddy. Please try again later."
    exit 1
fi
mkdir /etc/caddy
touch /etc/caddy/Caddyfile
chown -R root:www-data /etc/caddy
mkdir /etc/ssl/caddy
chown -R www-data:root /etc/ssl/caddy
chmod 0770 /etc/ssl/caddy
curl -s https://raw.githubusercontent.com/mholt/caddy/master/dist/init/linux-systemd/caddy.service -o /etc/systemd/system/caddy.service
chown www-data:www-data /var/log/caddy
#Set Caddy Proxy
cat > /etc/caddy/v2ray <<EOF
${v2_domain}
{
  log /var/log/caddy/v2ray.log
  tls moqiaoduo@gmail.com
  proxy /misaka_network localhost:10000 {
    websocket
    header_upstream -Origin
  }
}
EOF

echo "3. Install v2ray_proxy"
wget -o /usr/bin/v2ray_proxy -c $v2ray_proxy_url
#Config
cat > /etc/v2ray/api_config.json <<EOF
{
    "key": "${key}",
    "address": "127.0.0.1:8080"
}
EOF
#Set Caddy Proxy
cat > /etc/caddy/v2_api <<EOF
${api_domain}
{
  log /var/log/caddy/api.log
  tls moqiaoduo@gmail.com
  proxy / localhost:8080 {
    header_upstream -Origin
  }
}
EOF
cat > /etc/systemd/system/v2ray-proxy.service <<EOF
[Unit]
Description=V2Ray HTTP API WEB Proxy
After=network.target v2ray.service
Wants=network.target v2ray.service

[Service]
Restart=on-failure
Type=simple
PIDFile=/run/v2ray.pid
ExecStart=/usr/bin/v2ray_proxy

[Install]
WantedBy=multi-user.target
EOF

echo "4. Run and test"
systemctl daemon-reload
systemctl enable caddy.service
systemctl start v2ray.service
systemctl enable caddy.service
systemctl start caddy.service
# Disable and stop firewalld
systemctl disable firewalld
systemctl stop firewalld

#Finish
IP=`curl http://members.3322.org/dyndns/getip`

cat <<EOF

Final - Everything is OK!

-----------------------------
Server Info
-----------------------------
IP(Internet): ${IP}
V2Ray Domain: ${v2_domain}
API Domain: ${api_domain}
Port: 443
Default UUID: ${UUID}
AlterID: 64

streamSettings:
    network: ws
    security: tls
    wsSettings:
        path: /misaka_network

-----------------------------
Enjoy your day!
EOF

