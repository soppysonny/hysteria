#!/bin/bash

# Hysteria 日志查看脚本
# 用法: ./view-logs.sh <server_ip> [option]
# 示例: ./view-logs.sh 220.154.128.69
#       ./view-logs.sh 220.154.128.69 error
#       ./view-logs.sh 220.154.128.69 today

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}错误: 缺少服务器 IP 参数${NC}"
    echo ""
    echo "用法: $0 <server_ip> [option]"
    echo ""
    echo "选项:"
    echo "  (无)      - 实时查看日志 (默认)"
    echo "  live      - 实时查看日志"
    echo "  latest    - 查看最近 50 条日志"
    echo "  error     - 查看最近 50 条错误日志"
    echo "  today     - 查看今天的所有日志"
    echo "  hour      - 查看最近 1 小时的日志"
    echo "  status    - 查看服务状态"
    echo "  search    - 搜索日志 (需要额外参数)"
    echo ""
    echo "示例:"
    echo "  $0 220.154.128.69              # 实时日志"
    echo "  $0 220.154.128.69 error        # 错误日志"
    echo "  $0 220.154.128.69 search alice # 搜索包含 'alice' 的日志"
    exit 1
fi

SERVER_IP=$1
SSH_USER=${SSH_USER:-root}
OPTION=${2:-live}
SEARCH_TERM=$3

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Hysteria 日志查看工具${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "服务器: ${SSH_USER}@${SERVER_IP}"
echo "操作: ${OPTION}"
echo ""

# 测试 SSH 连接
echo -e "${YELLOW}测试 SSH 连接...${NC}"
if ! ssh -o ConnectTimeout=5 ${SSH_USER}@${SERVER_IP} "echo 'SSH 连接成功'" 2>/dev/null; then
    echo -e "${RED}错误: 无法连接到服务器 ${SSH_USER}@${SERVER_IP}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH 连接正常${NC}"
echo ""

# 根据选项执行相应命令
case $OPTION in
    live)
        echo -e "${YELLOW}实时查看 Hysteria 日志 (按 Ctrl+C 退出)...${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria -f"
        ;;

    latest)
        echo -e "${YELLOW}最近 50 条日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria -n 50 --no-pager"
        ;;

    error)
        echo -e "${YELLOW}最近 50 条错误日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria -p err -n 50 --no-pager"
        ;;

    today)
        echo -e "${YELLOW}今天的所有日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria --since today --no-pager"
        ;;

    hour)
        echo -e "${YELLOW}最近 1 小时的日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria --since '1 hour ago' --no-pager"
        ;;

    status)
        echo -e "${YELLOW}服务状态:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "systemctl status hysteria --no-pager -l"
        echo ""
        echo -e "${YELLOW}最近 10 条日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria -n 10 --no-pager"
        ;;

    search)
        if [ -z "$SEARCH_TERM" ]; then
            echo -e "${RED}错误: search 选项需要搜索关键词${NC}"
            echo "用法: $0 $SERVER_IP search <关键词>"
            exit 1
        fi
        echo -e "${YELLOW}搜索包含 '${SEARCH_TERM}' 的日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria --no-pager | grep -i '${SEARCH_TERM}' | tail -50"
        ;;

    export)
        EXPORT_FILE="hysteria-logs-$(date +%Y%m%d_%H%M%S).log"
        echo -e "${YELLOW}导出日志到本地文件: ${EXPORT_FILE}${NC}"
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria -n 1000 --no-pager" > "$EXPORT_FILE"
        echo -e "${GREEN}✓ 日志已导出到: ${EXPORT_FILE}${NC}"
        echo "文件大小: $(ls -lh "$EXPORT_FILE" | awk '{print $5}')"
        ;;

    tail)
        COUNT=${3:-100}
        echo -e "${YELLOW}最近 ${COUNT} 条日志:${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria -n ${COUNT} --no-pager"
        ;;

    full)
        echo -e "${YELLOW}所有日志 (可能很长):${NC}"
        echo ""
        ssh ${SSH_USER}@${SERVER_IP} "journalctl -u hysteria --no-pager"
        ;;

    *)
        echo -e "${RED}未知选项: ${OPTION}${NC}"
        echo ""
        echo "可用选项: live, latest, error, today, hour, status, search, export, tail, full"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
