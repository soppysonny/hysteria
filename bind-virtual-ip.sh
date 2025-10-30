#!/bin/bash

# 虚拟IP永久绑定脚本（支持批量绑定）
# 用法: ./bind-virtual-ip.sh <server_ip> <virtual_ip> [netmask]
# 示例: ./bind-virtual-ip.sh 220.154.128.69 10.0.1.4
#       ./bind-virtual-ip.sh 220.154.128.69 10.0.1.5 255.255.255.0
#       ./bind-virtual-ip.sh 220.154.128.69 10.0.1.4,10.0.1.5,10.0.1.6 255.255.255.0

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
    echo "      $0 220.154.128.69 10.0.1.4,10.0.1.5,10.0.1.6 255.255.255.0"
    exit 1
fi

SERVER_IP=$1
VIRTUAL_IPS=$2
SSH_USER=${SSH_USER:-root}
NETMASK=${3:-255.255.255.0}
NETWORK_INTERFACE="eth0"

# 将逗号分隔的IP转换为数组
IFS=',' read -ra IP_ARRAY <<< "$VIRTUAL_IPS"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}虚拟IP永久绑定配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "服务器: ${SSH_USER}@${SERVER_IP}"
echo "虚拟IP数量: ${#IP_ARRAY[@]}"
echo "虚拟IP列表: ${VIRTUAL_IPS}"
echo "子网掩码: ${NETMASK}"
echo "网卡: ${NETWORK_INTERFACE}"
echo ""

# 验证所有虚拟IP格式
echo -e "${YELLOW}[1/7] 验证IP地址格式...${NC}"
for VIRTUAL_IP in "${IP_ARRAY[@]}"; do
    if ! echo "${VIRTUAL_IP}" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        echo -e "${RED}错误: 无效的IP地址格式: ${VIRTUAL_IP}${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ ${VIRTUAL_IP} 格式有效${NC}"
done
echo ""

# 测试SSH连接
echo -e "${YELLOW}[2/7] 测试 SSH 连接...${NC}"
if ! ssh -o ConnectTimeout=5 ${SSH_USER}@${SERVER_IP} "echo 'SSH 连接成功'" 2>/dev/null; then
    echo -e "${RED}错误: 无法连接到服务器${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH 连接正常${NC}"
echo ""

# 检查当前IP配置
echo -e "${YELLOW}[3/7] 检查当前网络配置...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE}"
echo ""

# 检查虚拟IP是否已经绑定
echo -e "${YELLOW}[4/7] 检查虚拟IP是否已存在...${NC}"
HAS_ERROR=0
for VIRTUAL_IP in "${IP_ARRAY[@]}"; do
    if ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE} | grep -q '${VIRTUAL_IP}/'"; then
        echo -e "${YELLOW}⚠ 虚拟IP ${VIRTUAL_IP} 已经存在于 ${NETWORK_INTERFACE}${NC}"
        HAS_ERROR=1
    else
        echo -e "${GREEN}✓ ${VIRTUAL_IP} 未占用${NC}"
    fi
done
if [ $HAS_ERROR -eq 1 ]; then
    echo -e "${RED}部分IP已存在，请使用其他IP地址或先删除现有配置${NC}"
    exit 1
fi
echo ""

# 自动检测下一个可用的别名编号
echo -e "${YELLOW}[5/7] 检测可用的网卡别名编号...${NC}"
START_ALIAS_NUM=$(ssh ${SSH_USER}@${SERVER_IP} "
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
echo -e "${GREEN}✓ 起始别名编号: ${START_ALIAS_NUM}${NC}"
echo ""

# 批量创建虚拟网卡配置文件并启用
echo -e "${YELLOW}[6/7] 创建虚拟网卡配置文件并启用...${NC}"
ALIAS_NUM=$START_ALIAS_NUM
SUCCESS_COUNT=0
declare -a SUCCESS_IPS
declare -a SUCCESS_ALIASES

for VIRTUAL_IP in "${IP_ARRAY[@]}"; do
    echo -e "${YELLOW}正在配置: ${VIRTUAL_IP} -> ${NETWORK_INTERFACE}:${ALIAS_NUM}${NC}"

    # 创建配置文件
    ssh ${SSH_USER}@${SERVER_IP} "cat > /etc/sysconfig/network-scripts/ifcfg-${NETWORK_INTERFACE}:${ALIAS_NUM} <<'EOF'
DEVICE=${NETWORK_INTERFACE}:${ALIAS_NUM}
BOOTPROTO=static
IPADDR=${VIRTUAL_IP}
NETMASK=${NETMASK}
ONBOOT=yes
EOF
"

    # 启用虚拟网卡
    ssh ${SSH_USER}@${SERVER_IP} "ifup ${NETWORK_INTERFACE}:${ALIAS_NUM} 2>&1 || echo '虚拟网卡可能已启用'"

    # 验证
    if ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE} | grep -q '${VIRTUAL_IP}/'"; then
        echo -e "${GREEN}✓ ${VIRTUAL_IP} 配置成功${NC}"
        SUCCESS_IPS+=("${VIRTUAL_IP}")
        SUCCESS_ALIASES+=("${NETWORK_INTERFACE}:${ALIAS_NUM}")
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ ${VIRTUAL_IP} 配置失败${NC}"
    fi

    ((ALIAS_NUM++))
    echo ""
done

echo -e "${GREEN}成功配置 ${SUCCESS_COUNT}/${#IP_ARRAY[@]} 个虚拟IP${NC}"
echo ""

# 验证所有IP配置
echo -e "${YELLOW}[7/7] 验证所有IP配置...${NC}"
for VIRTUAL_IP in "${SUCCESS_IPS[@]}"; do
    VERIFY_OUTPUT=$(ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE} | grep '${VIRTUAL_IP}'")
    echo "$VERIFY_OUTPUT"
done
echo ""

# 显示完整配置
echo -e "${YELLOW}当前网卡配置:${NC}"
ssh ${SSH_USER}@${SERVER_IP} "ip addr show ${NETWORK_INTERFACE}"
echo ""

if [ $SUCCESS_COUNT -eq ${#IP_ARRAY[@]} ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 所有虚拟IP配置完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}⚠ 部分虚拟IP配置完成${NC}"
    echo -e "${YELLOW}========================================${NC}"
fi
echo ""
echo "成功配置的虚拟IP (${SUCCESS_COUNT}/${#IP_ARRAY[@]}):"
for i in "${!SUCCESS_IPS[@]}"; do
    echo "  - ${SUCCESS_IPS[$i]} (${SUCCESS_ALIASES[$i]})"
done
echo ""
echo "子网掩码: ${NETMASK}"
echo "配置目录: /etc/sysconfig/network-scripts/"
echo "重启后自动生效: 是 (ONBOOT=yes)"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. 重启 Hysteria 服务: ssh ${SSH_USER}@${SERVER_IP} 'systemctl restart hysteria'"
echo "2. 查看日志确认无错误: ssh ${SSH_USER}@${SERVER_IP} 'journalctl -u hysteria -f'"
echo ""
echo -e "${YELLOW}测试虚拟IP是否工作:${NC}"
for VIRTUAL_IP in "${SUCCESS_IPS[@]}"; do
    echo "ssh ${SSH_USER}@${SERVER_IP} 'curl --interface ${VIRTUAL_IP} https://1.1.1.1 -I'"
done
echo ""
