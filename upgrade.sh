#!/bin/sh
v2ray_proxy_url=`curl -s https://api.github.com/repos/misakanetwork2018/v2ray-api/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url"`
if [ ! -n "$v2ray_proxy_url" ]; then
echo "Get V2ray Api Download URL Failed. Please try again."
exit;
fi

echo "upgrade v2ray-proxy only"
systemctl stop v2ray-proxy
wget --no-check-certificate -O /usr/bin/v2ray_proxy $v2ray_proxy_url
chmod a+x /usr/bin/v2ray_proxy
systemctl restart v2ray
systemctl start v2ray-proxy
echo "Everything is OK!"
