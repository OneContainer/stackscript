#!/bin/bash

apt-get update
apt-get install software-properties-common -y
add-apt-repository ppa:max-c-lv/shadowsocks-libev -y
apt-get update
apt-get install -y -qq supervisor shadowsocks-libev

apt-get install --no-install-recommends build-essential autoconf libtool libssl-dev libpcre3-dev libev-dev asciidoc xmlto automake
git clone --recursive https://github.com/shadowsocks/simple-obfs.git
cd simple-obfs && ./autogen.sh
./configure && make && make install

PORTS_USED=`netstat -antl |grep LISTEN | awk '{ print $4 }' | cut -d: -f2|sed '/^$/d'|sort`
PORTS_USED=`echo $PORTS_USED|sed 's/\s/$\|^/g'`
PORTS_USED="^${PORTS_USED}$"

SS_PASSWORD=`dd if=/dev/urandom bs=32 count=1 | md5sum | cut -c-32`
SS_PORT=`seq 1025 9000 | grep -v -E "$PORTS_USED" | shuf -n 1`
SS_LB_PORT=`seq 1025 9000 | grep -v -E "$PORTS_USED $SS_PORT" | shuf -n 1`

wget https://raw.githubusercontent.com/OneContainer/stackscript/master/shadowsocks.json -O /etc/shadowsocks.json
wget https://raw.githubusercontent.com/OneContainer/stackscript/master/shadowsocks.conf -O /etc/supervisor/conf.d/shadowsocks.conf
wget https://raw.githubusercontent.com/OneContainer/stackscript/master/local.conf -O /etc/sysctl.d/local.conf

sed -i -e s/SS_PASSWORD/$SS_PASSWORD/ /etc/shadowsocks.json
sed -i -e s/SS_PORT/$SS_PORT/ /etc/shadowsocks.json
sed -i -e s/SS_LB_PORT/$SS_LB_PORT/ /etc/shadowsocks.json

bash <(curl -L -s https://install.direct/go.sh)
wget https://raw.githubusercontent.com/OneContainer/stackscript/master/v2ray/config.json -O /etc/v2ray/config.json

V2RAY_UUID=`curl -s -X GET https://www.uuidgenerator.net/ | grep -Po '(?<=^<h2 class="uuid">)[a-z0-9-]+'`
V2RAY_PORT=`seq 1025 9000 | grep -v -E "$PORTS_USED $SS_PORT $SS_LB_PORT" | shuf -n 1`

sed -i -e s/V2RAY_UUID/$V2RAY_UUID/ /etc/v2ray/config.json
sed -i -e s/V2RAY_PORT/$V2RAY_PORT/ /etc/v2ray/config.json

sysctl --system

service supervisor stop
echo 'ulimit -n 51200' >> /etc/default/supervisor
service supervisor start
service v2ray start

supervisorctl reload

# sysctl net.ipv4.tcp_available_congestion_control
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

echo "\n*******shadowsocks configuration*******"
echo "Port: $SS_PORT"
echo "Load balance port: $SS_LB_PORT"
echo "Password: $SS_PASSWORD"
echo "\n*******v2ray configuration*******"
echo "Port: $V2RAY_PORT"
echo "UUID: $V2RAY_UUID"
