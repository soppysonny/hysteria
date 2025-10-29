#!/bin/bash

# 虚拟IP永久绑定脚本
# 用法: ./bind-virtual-ip.sh <server_ip> <virtual_ip> [netmask]
# 示例: ./bind-virtual-ip.sh 220.154.128.69 10.0.1.4
#       ./bind-virtual-ip.sh 220.154.128.69 10.0.1.5 255.255.255.0

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo -e "${RED}错误: 缺少必需参数${NC}"
    echo "用法: $0 <server_ip> <virtual_ip> [netmask]"
    echo "示例: $0 220.154.128.69 10.0.1.4"
    echo "      $0 220.154.128.69 10.0.1.5 255.255.255.0"
    exit 1
fi

SERVER_IP=$1
VIRTUAL_IP=$2
SSH_USER=${SSH_USER:-root}
NETMASK=${3:-255.255.255.0}
NETWORK_INTERFACE="eth0"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}虚拟IP永久绑定配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "服务器: ${SSH_USER}@${SERVER_IP}"
echo "虚拟IP: ${VIRTUAL_IP}"
echo "子网掩码: ${NETMASK}"
echo "网卡: ${NETWORK_INTERFACE}"
echo ""

# 验证虚拟IP格式
if ! echo "${VIRTUAL_IP}" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo -e "${RED}错误: 无效的IP地址格式: ${VIRTUAL_IP}${NC}"
    exit 1
fi

# 测试SSH连接
echo -e "${YELLOW}[1/7] 测试 SSH 连接...${NC}"
if ! ssh -o ConnectTimeout=5 ${SSH_USER}@${SERVER_IP} "echo 'SSH 连接成功'" 2>/dev/null; then
    echo -e "${RED}错误: 无法连接到服务器${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH 连接正常${NC}"
echo ""

# 检查当前IP配置
echo -e "${YELLOW}[2/7] 检查当前网络配置...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE}"
echo ""

# 检查虚拟IP是否已经绑定
echo -e "${YELLOW}[3/7] 检查虚拟IP是否已存在...${NC}"
if ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE} | grep -q '${VIRTUAL_IP}/'"; then
    echo -e "${YELLOW}⚠ 虚拟IP ${VIRTUAL_IP} 已经存在于 ${NETWORK_INTERFACE}${NC}"
    echo "请使用其他IP地址或先删除现有配置"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟IP未占用${NC}"
echo ""

# 自动检测下一个可用的别名编号
echo -e "${YELLOW}[4/7] 检测可用的网卡别名编号...${NC}"
ALIAS_NUM=$(ssh ${SSH_USER}@${SERVER_IP} "
    max_num=-1
    for config in /etc/sysconfig/network-scripts/ifcfg-${NETWORK_INTERFACE}:*; do
        if [ -f \"\$config\" ]; then
            num=\$(basename \"\$config\" | sed 's/.*://')
            if [ \"\$num\" -gt \"\$max_num\" ] 2>/dev/null; then
                max_num=\$num
            fi
        fi
    done
    echo \$((max_num + 1))
")
echo -e "${GREEN}✓ 使用别名: ${NETWORK_INTERFACE}:${ALIAS_NUM}${NC}"
echo ""

# 创建虚拟网卡配置文件
echo -e "${YELLOW}[5/7] 创建虚拟网卡配置文件...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "cat > /etc/sysconfig/network-scripts/ifcfg-${NETWORK_INTERFACE}:${ALIAS_NUM} <<'EOF'
DEVICE=${NETWORK_INTERFACE}:${ALIAS_NUM}
BOOTPROTO=static
IPADDR=${VIRTUAL_IP}
NETMASK=${NETMASK}
ONBOOT=yes
EOF
"
echo -e "${GREEN}✓ 配置文件已创建: /etc/sysconfig/network-scripts/ifcfg-${NETWORK_INTERFACE}:${ALIAS_NUM}${NC}"
echo ""

# 启用虚拟网卡
echo -e "${YELLOW}[6/7] 启用虚拟网卡...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "ifup ${NETWORK_INTERFACE}:${ALIAS_NUM} 2>&1 || echo '虚拟网卡可能已启用'"
echo ""

# 验证IP配置
echo -e "${YELLOW}[7/7] 验证IP配置...${NC}"
VERIFY_OUTPUT=$(ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE} | grep '${VIRTUAL_IP}'")
if [ -n "$VERIFY_OUTPUT" ]; then
    echo -e "${GREEN}✓ 虚拟IP配置成功！${NC}"
    echo "$VERIFY_OUTPUT"
else
    echo -e "${RED}✗ 虚拟IP配置失败${NC}"
    echo "请检查网络配置"
    exit 1
fi
echo ""

# 显示完整配置
echo -e "${YELLOW}当前网卡配置:${NC}"
ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 虚拟IP配置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "虚拟IP: ${VIRTUAL_IP}"
echo "子网掩码: ${NETMASK}"
echo "网卡别名: ${NETWORK_INTERFACE}:${ALIAS_NUM}"
echo "配置文件: /etc/sysconfig/network-scripts/ifcfg-${NETWORK_INTERFACE}:${ALIAS_NUM}"
echo "重启后自动生效: 是 (ONBOOT=yes)"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. 重启 Hysteria 服务: ssh ${SSH_USER}@${SERVER_IP} 'systemctl restart hysteria'"
echo "2. 查看日志确认无错误: ssh ${SSH_USER}@${SERVER_IP} 'journalctl -u hysteria -f'"
echo ""
echo -e "${YELLOW}测试虚拟IP是否工作:${NC}"
echo "ssh ${SSH_USER}@${SERVER_IP} 'curl --interface ${VIRTUAL_IP} https://1.1.1.1 -I'"
echo ""
