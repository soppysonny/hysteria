#!/bin/bash

# Hysteria2 服务器更新脚本
# 用法: ./update-hysteria.sh <server_ip> [ssh_user]
# 示例: ./update-hysteria.sh 220.154.128.69
#       ./update-hysteria.sh 220.154.128.69 root

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}错误: 缺少服务器 IP 参数${NC}"
    echo "用法: $0 <server_ip> [ssh_user]"
    echo "示例: $0 220.154.128.69"
    echo "      $0 220.154.128.69 root"
    exit 1
fi

SERVER_IP=$1
SSH_USER=${2:-root}
BINARY_PATH="./hysteria-linux-amd64"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Hysteria2 服务器更新脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "目标服务器: ${SSH_USER}@${SERVER_IP}"
echo "备份时间戳: ${BACKUP_DATE}"
echo ""

# 检查本地二进制文件
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}错误: 找不到 ${BINARY_PATH}${NC}"
    echo "请确保在 Hysteria 项目目录下执行此脚本"
    exit 1
fi

echo -e "${YELLOW}[1/8] 检查本地二进制文件...${NC}"
ls -lh "$BINARY_PATH"
echo ""

# 测试 SSH 连接
echo -e "${YELLOW}[2/8] 测试 SSH 连接...${NC}"
if ! ssh -o ConnectTimeout=5 ${SSH_USER}@${SERVER_IP} "echo 'SSH 连接成功'" 2>/dev/null; then
    echo -e "${RED}错误: 无法连接到服务器 ${SSH_USER}@${SERVER_IP}${NC}"
    echo "请检查:"
    echo "  1. SSH 密钥是否正确配置"
    echo "  2. 服务器 IP 是否正确"
    echo "  3. 防火墙是否允许 SSH 连接"
    exit 1
fi
echo -e "${GREEN}✓ SSH 连接正常${NC}"
echo ""

# 检查服务器上的 Hysteria 安装
echo -e "${YELLOW}[3/8] 检查服务器当前安装...${NC}"
HYSTERIA_PATH=$(ssh ${SSH_USER}@${SERVER_IP} "which hysteria 2>/dev/null || echo ''")
if [ -z "$HYSTERIA_PATH" ]; then
    echo -e "${RED}警告: 未找到 hysteria 可执行文件${NC}"
    echo "假设安装路径为 /usr/local/bin/hysteria"
    HYSTERIA_PATH="/usr/local/bin/hysteria"
else
    echo -e "${GREEN}✓ 找到 Hysteria: ${HYSTERIA_PATH}${NC}"
fi

# 检查 systemd 服务
SERVICE_STATUS=$(ssh ${SSH_USER}@${SERVER_IP} "systemctl is-active hysteria 2>/dev/null || echo 'inactive'")
echo "服务状态: ${SERVICE_STATUS}"
echo ""

# 备份当前版本
echo -e "${YELLOW}[4/8] 备份当前版本...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "
    if [ -f ${HYSTERIA_PATH} ]; then
        cp ${HYSTERIA_PATH} ${HYSTERIA_PATH}.backup.${BACKUP_DATE}
        echo '✓ 已备份到: ${HYSTERIA_PATH}.backup.${BACKUP_DATE}'
    else
        echo '⚠ 原文件不存在，跳过备份'
    fi

    if [ -f /etc/hysteria/config.yaml ]; then
        mkdir -p /etc/hysteria/backups
        cp /etc/hysteria/config.yaml /etc/hysteria/backups/config.yaml.backup.${BACKUP_DATE}
        echo '✓ 已备份配置: /etc/hysteria/backups/config.yaml.backup.${BACKUP_DATE}'
    fi
"
echo ""

# 停止服务
echo -e "${YELLOW}[5/8] 停止 Hysteria 服务...${NC}"
if [ "$SERVICE_STATUS" = "active" ]; then
    ssh ${SSH_USER}@${SERVER_IP} "systemctl stop hysteria"
    echo -e "${GREEN}✓ 服务已停止${NC}"
else
    echo "⚠ 服务未运行，跳过停止"
fi
echo ""

# 上传新版本
echo -e "${YELLOW}[6/8] 上传新版本...${NC}"
scp ${BINARY_PATH} ${SSH_USER}@${SERVER_IP}:/tmp/hysteria-new
echo -e "${GREEN}✓ 上传完成${NC}"
echo ""

# 替换可执行文件
echo -e "${YELLOW}[7/8] 替换可执行文件...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "
    chmod +x /tmp/hysteria-new
    mv /tmp/hysteria-new ${HYSTERIA_PATH}
    echo '✓ 已替换: ${HYSTERIA_PATH}'
"
echo ""

# 启动服务
echo -e "${YELLOW}[8/8] 启动 Hysteria 服务...${NC}"
ssh ${SSH_USER}@${SERVER_IP} "
    if systemctl is-enabled hysteria >/dev/null 2>&1; then
        systemctl start hysteria
        sleep 2
        systemctl status hysteria --no-pager -l | head -15
    else
        echo '⚠ systemd 服务未配置，请手动启动'
    fi
"
echo ""

# 验证服务状态
echo -e "${YELLOW}验证服务状态...${NC}"
FINAL_STATUS=$(ssh ${SSH_USER}@${SERVER_IP} "systemctl is-active hysteria 2>/dev/null || echo 'unknown'")
if [ "$FINAL_STATUS" = "active" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 更新成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "服务状态: ${FINAL_STATUS}"
    echo "备份位置: ${HYSTERIA_PATH}.backup.${BACKUP_DATE}"
    echo ""
    echo "查看日志: ssh ${SSH_USER}@${SERVER_IP} 'journalctl -u hysteria -f'"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}⚠ 更新完成但服务状态异常${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "服务状态: ${FINAL_STATUS}"
    echo "请检查日志: ssh ${SSH_USER}@${SERVER_IP} 'journalctl -u hysteria -n 50'"
    echo ""
    echo "如需回滚:"
    echo "  ssh ${SSH_USER}@${SERVER_IP} 'systemctl stop hysteria && mv ${HYSTERIA_PATH}.backup.${BACKUP_DATE} ${HYSTERIA_PATH} && systemctl start hysteria'"
    exit 1
fi

# 显示版本信息
echo -e "${YELLOW}新版本信息:${NC}"
ssh ${SSH_USER}@${SERVER_IP} "${HYSTERIA_PATH} version 2>/dev/null || echo '版本命令不可用'"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}更新完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "如遇问题可回滚到之前版本:"
echo "  ssh ${SSH_USER}@${SERVER_IP}"
echo "  systemctl stop hysteria"
echo "  mv ${HYSTERIA_PATH}.backup.${BACKUP_DATE} ${HYSTERIA_PATH}"
echo "  systemctl start hysteria"
echo ""
