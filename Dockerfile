# ============================================================
# netbox:rocky - 网络排查工具箱（Rocky Linux 9）
# 特点：yum 源已换阿里云，Pod 内可直接 yum install 想要的工具
# ============================================================
FROM rockylinux:9

LABEL maintainer="ops@example.com" \
      description="Network debug toolbox based on Rocky Linux 9 (yum ready)" \
      version="1.1"

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai

# ------------------------------------------------------------
# 1) 换阿里云源：既加速构建，也让 Pod 内 yum install 可用
#    换其他源：把 mirrors.aliyun.com/rockylinux 替换成
#      mirrors.tuna.tsinghua.edu.cn/rocky
#      repo.huaweicloud.com/rocky
# ------------------------------------------------------------
RUN set -eux; \
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
        -i.bak /etc/yum.repos.d/rocky*.repo; \
    dnf -y makecache

# ------------------------------------------------------------
# 2) 优化 dnf 全局配置（Pod 内安装也会生效：不装文档、不装弱依赖）
# ------------------------------------------------------------
RUN printf '%s\n' \
      'tsflags=nodocs' \
      'install_weak_deps=False' \
      'keepcache=0' \
      'max_parallel_downloads=10' \
      >> /etc/dnf/dnf.conf

# ------------------------------------------------------------
# 3) 装 EPEL（mtr / ipvsadm / conntrack 等在这里），同样换阿里云
# ------------------------------------------------------------
RUN set -eux; \
    dnf install -y epel-release; \
    sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download[^/]*/pub/epel|baseurl=https://mirrors.aliyun.com/epel|g' \
        -i /etc/yum.repos.d/epel*.repo; \
    dnf -y makecache

# ------------------------------------------------------------
# 4) 安装网络工具
#    --allowerasing 用于把 curl-minimal 换成完整版 curl（支持 telnet:// 等协议）
# ------------------------------------------------------------
RUN set -eux; \
    dnf install -y --allowerasing \
# ---- 你点名要的命令 ----
      bind-utils \
      curl \
      iputils \
      telnet \
      mtr \
      traceroute \
# ---- 网络栈查看 ----
      iproute \
      net-tools \
      ethtool \
# ---- 抓包 / 端口 ----
      tcpdump \
      nmap-ncat \
      socat \
# ---- HTTP / TLS / 传输 ----
      wget \
      openssl \
      openssh-clients \
# ---- K8s 网络排查 ----
      iptables-nft \
      conntrack-tools \
      ipvsadm \
# ---- 系统 & 杂项 ----
      procps-ng \
      psmisc \
      lsof \
      strace \
      hostname \
      tzdata \
      less \
      tar \
      gzip \
      which \
      jq \
      bash-completion \
    ; \
    dnf install -y iptables-legacy || true; \
    dnf clean all; \
    rm -rf /var/cache/dnf/* /var/log/dnf* /var/log/hawkey.log \
           /usr/share/man /usr/share/doc /usr/share/info /tmp/*; \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    echo 'Asia/Shanghai' > /etc/timezone

# ------------------------------------------------------------
# 5) 内置帮助命令 nethelp
# ------------------------------------------------------------
RUN cat > /usr/local/bin/nethelp <<'HELP' && chmod +x /usr/local/bin/nethelp
==================== netbox 常用命令 ====================
DNS      : dig +short <域名> | nslookup <域名> | host <域名>
连通性   : ping -c4 <ip> | traceroute -n <ip> | mtr -r -c5 <ip>
端口     : telnet <ip> <port> | nc -zv <ip> <port> | curl -v telnet://<ip>:<port>
HTTP     : curl -sv <url> | curl -o /dev/null -w '%{http_code}\n' <url>
网卡路由 : ip -br a | ip r | ss -lntp | netstat -anp
抓包     : tcpdump -i any -nn port 53 -c 20
K8s 网络 : iptables-nft -t nat -L -n | conntrack -L | ipvsadm -Ln
转发代理 : socat TCP-LISTEN:8080,fork TCP:svc:80
装新工具 : pkg <包名>      例: pkg nmap iperf3 mysql redis
=========================================================
HELP

# ------------------------------------------------------------
# 6) 交互体验：彩色提示符 + pkg 快捷别名
# ------------------------------------------------------------
RUN printf '%s\n' \
      'export PS1="\[\e[1;33m\]netbox\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "' \
      'alias ll="ls -alh"' \
      'alias pkg="yum install -y"' \
      'nethelp' \
      >> /root/.bashrc

WORKDIR /root

# 关键：保持容器常驻，方便 kubectl exec
CMD ["sleep", "infinity"]
