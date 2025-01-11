#!/usr/bin/env bash
#
# 使用 iptables/ipset 阻止端口扫描
#
# 如果有 IP 连接未开放端口，该 IP 将进入扫描者名单，过期时间 IP_DENY_SECOND 秒。
# 如果该 IP 继续连接未开放端口，过期时间不复位，但包计数器会累计，
# 如果累计超过 PORT_SCAN_MAX，该 IP 将无法连接任何端口，直到过期。
apt-get install ipset  iptables

IP_DENY_SECOND=10
PORT_SCAN_MAX=2

# 目标网卡
DEV=eth0


INPUT="-A INPUT"
# INPUT=-t raw -A PREROUTING


# 开放的端口
ipset create pub-port-set bitmap:port range 0-65535

# 如果应用程序端口有变化，需及时更新该 set，否则正常用户会被当成扫描者
ipset add pub-port-set 22
ipset add pub-port-set 999
ipset add pub-port-set 18080
# ipset add pub-port-set 443
# 添加更多端口 ...


# 名单最大条数
# 例如 100Mbps 网络下 IP_DENY_SECOND 秒能收到多少 SYN 包？（SYN 最小 60B）
IP_SET_MAX=$((100 * 1024 * 1024 / 8 / 60 * $IP_DENY_SECOND))

# 扫描者名单
ipset create scanner-ip-set hash:ip \
  timeout $IP_DENY_SECOND \
  maxelem $IP_SET_MAX \
  counters


## function trap-scan ##
iptables \
  -N trap-scan

# 更新扫描者 packets/bytes 计数器
iptables \
  -A trap-scan \
  -m set --match-set scanner-ip-set src \
  -j DROP

# 将 IP 加入扫描者名单（仅首次）
# 使用 iptables 动态改变 ipset，避免了额外的交互。本程序亮点~
iptables \
  -A trap-scan \
  -j SET \
  --add-set scanner-ip-set src

iptables \
  -A trap-scan \
  -j DROP
## end function ##


