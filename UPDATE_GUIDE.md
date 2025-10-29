# Hysteria2 服务器更新指南

## 自动更新脚本

已创建自动更新脚本 `update-hysteria.sh`，可以一键更新远程服务器上的 Hysteria2。

## 使用方法

### 基本用法

```bash
cd /Users/lava/Desktop/Hysteria
./update-hysteria.sh 220.154.128.69
```

### 指定 SSH 用户

```bash
./update-hysteria.sh 220.154.128.69 root
```

如果不指定用户，默认使用 `root`。

## 脚本功能

### 自动执行的操作

1. ✅ **检查本地文件** - 验证 `hysteria-linux-amd64` 存在
2. ✅ **测试 SSH 连接** - 确保可以连接到服务器
3. ✅ **检查当前安装** - 查找现有 Hysteria 安装位置
4. ✅ **备份当前版本** - 备份可执行文件和配置文件
5. ✅ **停止服务** - 安全停止 Hysteria 服务
6. ✅ **上传新版本** - 传输新的可执行文件
7. ✅ **替换文件** - 原子性替换旧版本
8. ✅ **启动服务** - 重新启动服务
9. ✅ **验证状态** - 检查服务是否正常运行

### 安全特性

- **自动备份**: 所有文件都会带时间戳备份
- **失败回滚**: 如果更新失败，提供回滚命令
- **服务检查**: 验证服务是否正常启动
- **详细日志**: 每步操作都有清晰的输出

## 执行示例

```bash
$ ./update-hysteria.sh 220.154.128.69
========================================
Hysteria2 服务器更新脚本
========================================

目标服务器: root@220.154.128.69
备份时间戳: 20251028_201500

[1/8] 检查本地二进制文件...
-rwxr-xr-x  1 lava  staff  19M Oct 28 20:18 ./hysteria-linux-amd64

[2/8] 测试 SSH 连接...
✓ SSH 连接正常

[3/8] 检查服务器当前安装...
✓ 找到 Hysteria: /usr/local/bin/hysteria
服务状态: active

[4/8] 备份当前版本...
✓ 已备份到: /usr/local/bin/hysteria.backup.20251028_201500
✓ 已备份配置: /etc/hysteria/backups/config.yaml.backup.20251028_201500

[5/8] 停止 Hysteria 服务...
✓ 服务已停止

[6/8] 上传新版本...
✓ 上传完成

[7/8] 替换可执行文件...
✓ 已替换: /usr/local/bin/hysteria

[8/8] 启动 Hysteria 服务...
● hysteria.service - Hysteria Server
   Loaded: loaded
   Active: active (running)
   ...

验证服务状态...
========================================
✓ 更新成功！
========================================

服务状态: active
备份位置: /usr/local/bin/hysteria.backup.20251028_201500

查看日志: ssh root@220.154.128.69 'journalctl -u hysteria -f'
```

## 前置要求

### 1. SSH 密钥配置

确保已配置 SSH 密钥认证：

```bash
# 如果还没有 SSH 密钥
ssh-keygen -t rsa -b 4096

# 复制公钥到服务器
ssh-copy-id root@220.154.128.69

# 测试连接
ssh root@220.154.128.69 "echo 'SSH 连接成功'"
```

### 2. 本地文件

确保以下文件存在：
- `./hysteria-linux-amd64` - 新版本可执行文件

### 3. 服务器要求

- 已安装 Hysteria2
- 配置了 systemd 服务
- SSH 端口开放 (默认 22)

## 故障排查

### SSH 连接失败

```bash
错误: 无法连接到服务器 root@220.154.128.69
```

**解决方案:**
1. 检查 SSH 密钥: `ssh root@220.154.128.69`
2. 检查防火墙: `telnet 220.154.128.69 22`
3. 验证 IP 地址是否正确

### 服务启动失败

```bash
⚠ 更新完成但服务状态异常
```

**解决方案:**

1. 查看日志:
```bash
ssh root@220.154.128.69 'journalctl -u hysteria -n 50'
```

2. 检查配置:
```bash
ssh root@220.154.128.69 'hysteria server -c /etc/hysteria/config.yaml --test'
```

3. 回滚到旧版本:
```bash
ssh root@220.154.128.69
systemctl stop hysteria
mv /usr/local/bin/hysteria.backup.20251028_201500 /usr/local/bin/hysteria
systemctl start hysteria
```

### 找不到 hysteria 命令

如果服务器上 Hysteria 安装在非标准位置，手动指定：

```bash
# 编辑脚本中的 HYSTERIA_PATH 变量
# 或者在服务器上创建符号链接
ssh root@220.154.128.69 'ln -s /path/to/hysteria /usr/local/bin/hysteria'
```

## 手动更新步骤 (备用方案)

如果自动脚本无法使用，可以手动执行：

```bash
# 1. 上传文件
scp hysteria-linux-amd64 root@220.154.128.69:/tmp/

# 2. SSH 到服务器
ssh root@220.154.128.69

# 3. 备份和替换
cp /usr/local/bin/hysteria /usr/local/bin/hysteria.backup.$(date +%Y%m%d)
systemctl stop hysteria
chmod +x /tmp/hysteria-linux-amd64
mv /tmp/hysteria-linux-amd64 /usr/local/bin/hysteria
systemctl start hysteria

# 4. 验证
systemctl status hysteria
journalctl -u hysteria -n 20
```

## 更新配置 (可选)

如果需要启用新的用户路由功能，更新配置文件：

```bash
# SSH 到服务器
ssh root@220.154.128.69

# 备份配置
cp /etc/hysteria/config.yaml /etc/hysteria/config.yaml.backup

# 编辑配置
vi /etc/hysteria/config.yaml
```

添加 `bindUser` 字段:

```yaml
outbounds:
  - name: user1-line
    type: direct
    bindUser: user1  # 新增：为用户 user1 绑定此线路

  - name: default
    type: direct
```

重启服务:
```bash
systemctl restart hysteria
```

## 回滚操作

### 自动回滚

脚本失败时会自动提供回滚命令。

### 手动回滚

```bash
ssh root@220.154.128.69

# 停止服务
systemctl stop hysteria

# 恢复旧版本 (替换时间戳)
mv /usr/local/bin/hysteria.backup.20251028_201500 /usr/local/bin/hysteria

# 如果配置也被修改，恢复配置
mv /etc/hysteria/backups/config.yaml.backup.20251028_201500 /etc/hysteria/config.yaml

# 启动服务
systemctl start hysteria

# 验证
systemctl status hysteria
```

## 批量更新

如果有多台服务器需要更新：

```bash
# 创建服务器列表
cat > servers.txt <<EOF
220.154.128.69
192.168.1.100
10.0.0.50
EOF

# 批量更新
while read server; do
    echo "更新服务器: $server"
    ./update-hysteria.sh $server
    echo "---"
done < servers.txt
```

## 定时自动更新 (可选)

创建 cron 任务定期检查更新：

```bash
# 创建检查脚本
cat > /usr/local/bin/check-hysteria-update.sh <<'EOF'
#!/bin/bash
cd /Users/lava/Desktop/Hysteria
git pull
make build
./update-hysteria.sh 220.154.128.69 > /var/log/hysteria-update.log 2>&1
EOF

chmod +x /usr/local/bin/check-hysteria-update.sh

# 添加 cron (每周日凌晨 2 点检查)
crontab -e
# 添加: 0 2 * * 0 /usr/local/bin/check-hysteria-update.sh
```

## 监控和日志

### 查看实时日志

```bash
ssh root@220.154.128.69 'journalctl -u hysteria -f'
```

### 查看最近错误

```bash
ssh root@220.154.128.69 'journalctl -u hysteria -p err -n 50'
```

### 检查服务状态

```bash
ssh root@220.154.128.69 'systemctl status hysteria'
```

### 查看端口监听

```bash
ssh root@220.154.128.69 'ss -ulnp | grep hysteria'
```

## 最佳实践

1. **测试环境先试** - 在测试服务器上先更新
2. **业务低峰期更新** - 避免高峰时段
3. **保留备份** - 至少保留 3 个历史版本
4. **监控告警** - 配置服务监控和告警
5. **文档记录** - 记录每次更新的时间和变更

## 安全建议

1. **使用 SSH 密钥** - 不要使用密码认证
2. **限制 SSH 访问** - 配置防火墙规则
3. **日志审计** - 定期检查更新日志
4. **版本控制** - 记录每个版本的 SHA256
5. **回滚测试** - 定期测试回滚流程

---

**脚本位置**: `/Users/lava/Desktop/Hysteria/update-hysteria.sh`
**使用方法**: `./update-hysteria.sh <server_ip> [ssh_user]`
**支持平台**: Linux (CentOS/RHEL/Ubuntu/Debian)
