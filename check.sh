#!/bin/bash
# netbox 镜像工具自检
CMDS="bash dig nslookup host \
curl wget openssl ssh scp \
ping telnet traceroute mtr \
ip ss ifconfig netstat route ethtool \
tcpdump nc socat \
iptables-nft conntrack ipvsadm \
jq lsof strace ps top pstree hostname \
yum dnf rpm"

fail=0
for c in $CMDS; do
  if command -v "$c" >/dev/null 2>&1; then
    printf "  \033[32mOK  \033[0m %s\n" "$c"
  else
    printf "  \033[31mMISS\033[0m %s\n" "$c"
    fail=1
  fi
done
echo "----------------------------------------"
[ $fail -eq 0 ] && echo -e "\033[32m全部工具就绪\033[0m" || echo -e "\033[31m有缺失，请检查\033[0m"
exit $fail
