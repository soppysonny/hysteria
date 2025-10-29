# Hysteria User-Routing 部署指南

## 构建成果

已成功构建 Linux AMD64 版本，包含用户路由功能：

- **二进制文件**: `hysteria-linux-amd64` (19MB)
- **发布包**: `hysteria-linux-amd64-user-routing.tar.gz` (7.1MB)
- **位置**: `/Users/lava/Desktop/Hysteria/`

## 快速部署 (CentOS/RHEL)

### 1. 上传文件到服务器

```bash
# 在本地机器上
scp hysteria-linux-amd64-user-routing.tar.gz root@your-server:/root/

# 或者直接上传单个文件
scp release-user-routing/hysteria-linux-amd64 root@your-server:/root/
```

### 2. 在服务器上安装

```bash
# 如果上传的是压缩包
cd /root
tar -xzf hysteria-linux-amd64-user-routing.tar.gz
chmod +x hysteria-linux-amd64
sudo mv hysteria-linux-amd64 /usr/local/bin/hysteria

# 验证安装
hysteria version
```

### 3. 创建配置目录和文件

```bash
# 创建配置目录
sudo mkdir -p /etc/hysteria

# 生成自签名证书 (测试用)
openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt -days 3650 -subj "/CN=hysteria.example.com"

# 创建配置文件
sudo cat > /etc/hysteria/config.yaml <<'EOF'
listen: :443

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: userpass
  userpass:
    alice: password123
    bob: password456
    charlie: password789

outbounds:
  # alice 的专用直连
  - name: alice-outbound
    type: direct
    bindUser: alice
    direct:
      mode: auto

  # bob 的 SOCKS5 代理 (需要先配置 SOCKS5 服务器)
  - name: bob-outbound
    type: socks5
    bindUser: bob
    socks5:
      addr: 127.0.0.1:1080
      username: socks_user
      password: socks_pass

  # 默认直连
  - name: default
    type: direct
    direct:
      mode: auto

bandwidth:
  up: 1 gbps
  down: 1 gbps
EOF
```

### 4. 配置 Systemd 服务

```bash
# 创建 systemd 服务文件
sudo cat > /etc/systemd/system/hysteria.service <<'EOF'
[Unit]
Description=Hysteria Server with User Routing
Documentation=https://v2.hysteria.network/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start hysteria

# 查看状态
sudo systemctl status hysteria

# 设置开机自启
sudo systemctl enable hysteria
```

### 5. 配置防火墙

```bash
# firewalld (CentOS/RHEL 7+)
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --reload

# iptables (传统方式)
sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT
sudo service iptables save
```

### 6. 验证服务

```bash
# 查看日志
sudo journalctl -u hysteria -f

# 查看端口监听
sudo ss -ulnp | grep 443
```

## 客户端配置示例

### Alice 的客户端配置

```yaml
server: your-server.com:443

auth: alice:password123

bandwidth:
  up: 100 mbps
  down: 500 mbps

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080
```

### Bob 的客户端配置

```yaml
server: your-server.com:443

auth: bob:password456

bandwidth:
  up: 50 mbps
  down: 200 mbps

socks5:
  listen: 127.0.0.1:1080
```

## 高级配置

### 配置 SOCKS5 上游代理 (如果 Bob 需要)

如果你想让 bob 的流量通过 SOCKS5 代理，需要先在服务器上配置一个 SOCKS5 服务：

```bash
# 使用 Dante 作为 SOCKS5 服务器 (示例)
sudo yum install -y dante-server  # CentOS
# 或
sudo apt install -y dante-server  # Ubuntu/Debian

# 配置 Dante
sudo cat > /etc/danted.conf <<'EOF'
logoutput: /var/log/danted.log

internal: 127.0.0.1 port = 1080
external: eth0

socksmethod: username
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    log: error
}

socks pass {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error
    socksmethod: username
}
EOF

# 添加 SOCKS5 用户
sudo useradd -r -s /bin/false socks_user
echo "socks_user:socks_pass" | sudo chpasswd

# 启动 Dante
sudo systemctl start danted
sudo systemctl enable danted
```

### 结合 ACL 规则

```yaml
outbounds:
  - name: alice-outbound
    type: direct
    bindUser: alice

  - name: bob-outbound
    type: socks5
    bindUser: bob
    socks5:
      addr: 127.0.0.1:1080

  - name: default
    type: direct

# ACL 规则会应用到所有用户
acl:
  inline:
    - reject(geoip:private)
    - reject(geosite:category-ads-all)
    - direct(all)
```

## 故障排查

### 查看实时日志

```bash
# 查看服务日志
sudo journalctl -u hysteria -f --no-pager

# 只看错误
sudo journalctl -u hysteria -p err -f
```

### 常见问题

1. **端口被占用**
```bash
# 查看 443 端口占用
sudo ss -ulnp | grep 443
```

2. **证书问题**
```bash
# 验证证书
openssl x509 -in /etc/hysteria/server.crt -text -noout
```

3. **权限问题**
```bash
# 检查配置文件权限
sudo ls -la /etc/hysteria/
sudo chmod 644 /etc/hysteria/config.yaml
sudo chmod 600 /etc/hysteria/server.key
```

4. **防火墙问题**
```bash
# 临时关闭防火墙测试
sudo systemctl stop firewalld
# 如果可以连接，说明是防火墙问题，记得重新开启并正确配置
sudo systemctl start firewalld
```

## 性能优化

### 系统参数优化

```bash
# 添加到 /etc/sysctl.conf
cat >> /etc/sysctl.conf <<EOF
# Hysteria 优化参数
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
EOF

# 应用配置
sudo sysctl -p
```

### 文件描述符限制

```bash
# 修改 systemd 服务文件中的 LimitNOFILE
sudo systemctl edit hysteria

# 添加以下内容
[Service]
LimitNOFILE=1048576
```

## 监控和维护

### 日志轮转

```bash
sudo cat > /etc/logrotate.d/hysteria <<'EOF'
/var/log/hysteria/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        systemctl reload hysteria > /dev/null 2>&1 || true
    endscript
}
EOF
```

### 自动更新脚本

```bash
cat > /usr/local/bin/update-hysteria.sh <<'EOF'
#!/bin/bash
systemctl stop hysteria
cp /usr/local/bin/hysteria /usr/local/bin/hysteria.backup
wget -O /usr/local/bin/hysteria https://your-update-url/hysteria-linux-amd64
chmod +x /usr/local/bin/hysteria
systemctl start hysteria
EOF

chmod +x /usr/local/bin/update-hysteria.sh
```

## 安全建议

1. **使用强密码**: 确保用户密码足够复杂
2. **定期更新**: 及时更新 Hysteria 到最新版本
3. **监控日志**: 定期检查日志，发现异常行为
4. **限制端口**: 只开放必要的端口
5. **使用正式证书**: 生产环境使用 Let's Encrypt 等正式证书

## 附加资源

- 官方文档: https://v2.hysteria.network/zh/docs/
- 用户路由功能文档: `USER_ROUTING_FEATURE.md`
- 配置示例: `config_example_user_routing.yaml`

---

**构建信息**
- 构建日期: 2025-10-28
- Go 版本: 使用系统 Go 版本
- 目标平台: Linux AMD64
- 构建参数: `-trimpath -ldflags "-s -w -buildid="`
