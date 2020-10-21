# v2ray_install

V2Ray+WS+TLS+Caddy+V2Ray-API

既然要一键，那就贯彻到底

Centos

`
yum install wget -y;wget --no-check-certificate -O ./install.sh https://raw.githubusercontent.com/misakanetwork2018/v2ray_install/master/install.sh;bash install.sh -a example.com -v example.net
`

Debian/Ubuntu

`
apt udpate;apt install wget -y;wget --no-check-certificate -O ./install.sh https://raw.githubusercontent.com/misakanetwork2018/v2ray_install/master/install.sh;bash install.sh -a example.com -v example.net
`

-k : 接口密钥，不填则由脚本生成

-a : API的域名，请提前解析到服务器

-v : V2Ray的域名，请提前解析到服务器

-r : 安装完成后运行程序

注意两个域名不能重复，否则会导致配置失败

安装完了就会显示服务器信息，记得保存一下UUID，或者复制一下vmess链接，如果是自动生成Key也要记得复制一下哦

升级命令：
`
wget --no-check-certificate -O ./upgrade.sh https://raw.githubusercontent.com/misakanetwork2018/v2ray_install/master/upgrade.sh;bash upgrade.sh
`
