# Hysteria 日志查看指南

## 快速查看日志

### 1. 实时查看日志（最常用）

```bash
# SSH 登录服务器后
journalctl -u hysteria -f
```

- `-f`: 持续跟踪显示最新日志（类似 `tail -f`）
- 按 `Ctrl + C` 退出

### 2. 查看最近的日志

```bash
# 查看最近 50 条日志
journalctl -u hysteria -n 50

# 查看最近 100 条日志
journalctl -u hysteria -n 100

# 不分页显示（一次性显示全部）
journalctl -u hysteria -n 50 --no-pager
```

### 3. 查看今天的日志

```bash
journalctl -u hysteria --since today
```

### 4. 查看特定时间段的日志

```bash
# 查看最近 1 小时
journalctl -u hysteria --since "1 hour ago"

# 查看最近 30 分钟
journalctl -u hysteria --since "30 minutes ago"

# 查看指定日期
journalctl -u hysteria --since "2025-10-28" --until "2025-10-29"

# 查看指定时间
journalctl -u hysteria --since "2025-10-28 14:00:00" --until "2025-10-28 15:00:00"
```

### 5. 只查看错误日志

```bash
# 查看错误级别日志
journalctl -u hysteria -p err

# 查看错误和警告
journalctl -u hysteria -p warning

# 查看最近 50 条错误
journalctl -u hysteria -p err -n 50
```

## 远程查看日志（不需要先 SSH 登录）

### 方法 1: 使用 SSH 一行命令

```bash
# 查看实时日志
ssh root@220.154.128.69 'journalctl -u hysteria -f'

# 查看最近 50 条
ssh root@220.154.128.69 'journalctl -u hysteria -n 50 --no-pager'

# 查看错误日志
ssh root@220.154.128.69 'journalctl -u hysteria -p err -n 50 --no-pager'
```

### 方法 2: 创建日志查看脚本

在本地创建脚本 `view-hysteria-logs.sh`:

```bash
#!/bin/bash
SERVER_IP=${1:-220.154.128.69}
ssh root@$SERVER_IP 'journalctl -u hysteria -f'
```

使用方法:
```bash
chmod +x view-hysteria-logs.sh
./view-hysteria-logs.sh 220.154.128.69
```

## 高级日志查看

### 1. 查看带时间戳的日志

```bash
# 显示详细时间戳
journalctl -u hysteria -n 50 -o verbose

# 短格式时间戳
journalctl -u hysteria -n 50 -o short-precise
```

### 2. 查看 JSON 格式日志（便于解析）

```bash
journalctl -u hysteria -n 50 -o json-pretty
```

### 3. 按优先级过滤

```bash
# 0: emerg (紧急)
# 1: alert (警报)
# 2: crit (严重)
# 3: err (错误)
# 4: warning (警告)
# 5: notice (注意)
# 6: info (信息)
# 7: debug (调试)

# 查看 warning 及以上级别
journalctl -u hysteria -p warning -n 50
```

### 4. 搜索特定关键词

```bash
# 搜索包含 "error" 的日志
journalctl -u hysteria | grep -i error

# 搜索包含特定 IP 的日志
journalctl -u hysteria | grep "192.168.1.100"

# 搜索用户相关日志
journalctl -u hysteria | grep "alice"
```

### 5. 反向查看（从旧到新）

```bash
journalctl -u hysteria -r -n 50
```

## 导出日志

### 1. 导出到文件

```bash
# 导出所有日志
journalctl -u hysteria > hysteria.log

# 导出最近 1000 条
journalctl -u hysteria -n 1000 > hysteria.log

# 导出今天的日志
journalctl -u hysteria --since today > hysteria-$(date +%Y%m%d).log
```

### 2. 远程导出到本地

```bash
# 从远程服务器导出日志到本地
ssh root@220.154.128.69 'journalctl -u hysteria -n 1000' > hysteria-remote.log

# 导出并压缩
ssh root@220.154.128.69 'journalctl -u hysteria --since "7 days ago"' | gzip > hysteria-week.log.gz
```

## 服务状态检查

### 查看服务状态

```bash
# 详细状态
systemctl status hysteria

# 简洁状态
systemctl is-active hysteria

# 是否开机自启
systemctl is-enabled hysteria
```

### 完整状态信息

```bash
systemctl status hysteria -l --no-pager
```

## 日志轮转配置

### 查看当前日志大小

```bash
# 查看 journal 日志占用空间
journalctl --disk-usage

# 查看 hysteria 日志大小
journalctl -u hysteria --disk-usage
```

### 清理旧日志

```bash
# 只保留最近 7 天
sudo journalctl --vacuum-time=7d

# 只保留 100MB
sudo journalctl --vacuum-size=100M

# 清理 hysteria 的旧日志
sudo journalctl --vacuum-time=7d -u hysteria
```

## 实用快捷脚本

### 创建日志查看别名

在本地 `~/.bashrc` 或 `~/.zshrc` 添加:

```bash
# Hysteria 日志别名
alias hy-log='ssh root@220.154.128.69 "journalctl -u hysteria -f"'
alias hy-log-error='ssh root@220.154.128.69 "journalctl -u hysteria -p err -n 50 --no-pager"'
alias hy-log-today='ssh root@220.154.128.69 "journalctl -u hysteria --since today --no-pager"'
alias hy-status='ssh root@220.154.128.69 "systemctl status hysteria"'
```

使用方法:
```bash
source ~/.bashrc  # 或 source ~/.zshrc
hy-log           # 实时查看日志
hy-log-error     # 查看错误
hy-status        # 查看状态
```

## 常见问题排查

### 1. 服务启动失败

```bash
# 查看启动失败原因
journalctl -u hysteria -n 50 --no-pager | grep -i error

# 查看系统引导日志
journalctl -b -u hysteria
```

### 2. 连接问题

```bash
# 查看包含 "connection" 的日志
journalctl -u hysteria | grep -i connection

# 查看最近的 TCP/UDP 请求
journalctl -u hysteria | grep -E "TCP|UDP" | tail -50
```

### 3. 认证问题

```bash
# 查看认证相关日志
journalctl -u hysteria | grep -i auth

# 查看客户端连接日志
journalctl -u hysteria | grep "client connected"
```

### 4. 性能问题

```bash
# 查看最近的警告和错误
journalctl -u hysteria -p warning --since "1 hour ago"

# 查看资源使用情况（如果有）
journalctl -u hysteria | grep -i "memory\|cpu\|bandwidth"
```

## 日志示例解读

### 正常运行日志

```
Oct 28 20:15:00 server hysteria[1234]: server up and running
Oct 28 20:15:05 server hysteria[1234]: client connected addr=1.2.3.4:5678 id=alice tx=1000000
Oct 28 20:15:10 server hysteria[1234]: TCP request addr=1.2.3.4:5678 id=alice reqAddr=google.com:443
```

### 错误日志

```
Oct 28 20:16:00 server hysteria[1234]: client disconnected addr=1.2.3.4:5678 id=alice error="timeout"
Oct 28 20:16:05 server hysteria[1234]: TCP error addr=1.2.3.4:5678 id=bob reqAddr=example.com:80 error="connection refused"
```

## 监控和告警

### 设置日志监控（可选）

```bash
# 监控错误日志并发送邮件（需要配置邮件）
journalctl -u hysteria -f | grep -i error | mail -s "Hysteria Error" admin@example.com

# 监控特定事件
journalctl -u hysteria -f | grep "connection refused" >> /var/log/hysteria-errors.log
```

### 配置 logrotate（可选）

创建 `/etc/logrotate.d/hysteria-custom`:

```
/var/log/hysteria/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

## 性能优化

### 限制日志级别（减少日志量）

如果日志太多，可以在配置文件中调整日志级别（如果 Hysteria 支持）:

```yaml
# 在 config.yaml 中（示例）
# log:
#   level: warn  # 只记录警告和错误
```

### 日志持久化设置

确保 systemd journal 日志持久化:

```bash
# 检查配置
cat /etc/systemd/journald.conf | grep Storage

# 如果是 Storage=volatile，改为 persistent
sudo sed -i 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

## 快速参考

### 最常用命令

```bash
# 1. 实时日志
journalctl -u hysteria -f

# 2. 最近 50 条
journalctl -u hysteria -n 50

# 3. 错误日志
journalctl -u hysteria -p err -n 50

# 4. 今天的日志
journalctl -u hysteria --since today

# 5. 服务状态
systemctl status hysteria
```

### 远程快速查看

```bash
# 实时日志
ssh root@220.154.128.69 'journalctl -u hysteria -f'

# 最近错误
ssh root@220.154.128.69 'journalctl -u hysteria -p err -n 20 --no-pager'
```

---

## 总结

**最常用的查看方式:**

1. **实时查看**: `journalctl -u hysteria -f`
2. **查看最近**: `journalctl -u hysteria -n 50`
3. **查看错误**: `journalctl -u hysteria -p err -n 50`
4. **远程查看**: `ssh root@IP 'journalctl -u hysteria -f'`

**记住**: 按 `Ctrl + C` 退出实时日志查看模式。
