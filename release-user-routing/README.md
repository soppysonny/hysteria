# Hysteria v2 - User-Based Routing Edition

## 版本信息

- **基础版本**: Hysteria v2 (基于最新 master 分支)
- **新增功能**: User-Based Routing (根据用户路由到不同的 outbound)
- **构建平台**: Linux AMD64 (适用于 CentOS/RHEL/Ubuntu/Debian 等)
- **构建日期**: 2025-10-28

## 新功能说明

此版本在原版 Hysteria v2 基础上增加了 **用户路由功能**，允许根据认证用户将流量路由到不同的 outbound。

### 主要特性

- ✅ 支持根据用户名自动选择 outbound
- ✅ 支持所有 outbound 类型 (direct, socks5, http)
- ✅ 支持所有认证方式 (password, userpass, http, command)
- ✅ 与 ACL 规则完全兼容
- ✅ 用户名匹配不区分大小写
- ✅ 同时支持 TCP 和 UDP 流量

### 快速开始

1. **部署二进制文件**
```bash
# 将 hysteria-linux-amd64 上传到服务器
chmod +x hysteria-linux-amd64
sudo mv hysteria-linux-amd64 /usr/local/bin/hysteria
```

2. **创建配置文件**
```bash
# 使用提供的示例配置
cp config_example_user_routing.yaml /etc/hysteria/config.yaml
# 编辑配置文件，修改证书路径和用户密码
vi /etc/hysteria/config.yaml
```

3. **启动服务**
```bash
# 直接运行
hysteria server -c /etc/hysteria/config.yaml

# 或使用 systemd (推荐)
# 创建 systemd 服务文件
sudo cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria Server with User Routing
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 启动并设置开机自启
sudo systemctl daemon-reload
sudo systemctl enable hysteria
sudo systemctl start hysteria
sudo systemctl status hysteria
```

### 配置示例

```yaml
listen: :443

tls:
  cert: /path/to/cert.pem
  key: /path/to/key.pem

auth:
  type: userpass
  userpass:
    alice: password123
    bob: password456

outbounds:
  # alice 的专用线路
  - name: alice-proxy
    type: direct
    bindUser: alice
    direct:
      mode: auto

  # bob 通过 SOCKS5 代理
  - name: bob-proxy
    type: socks5
    bindUser: bob
    socks5:
      addr: 127.0.0.1:1080
      username: socks_user
      password: socks_pass

  # 默认线路
  - name: default
    type: direct
    direct:
      mode: auto
```

### 使用场景

1. **多用户不同线路**
   - VIP 用户使用高速专线
   - 普通用户使用标准线路

2. **按地区分流**
   - 中国用户走一条线路
   - 海外用户走另一条线路

3. **混合代理**
   - 某些用户直连
   - 某些用户通过上游代理

4. **流量隔离**
   - 不同部门/项目使用独立的网络出口

## 文件说明

- `hysteria-linux-amd64` - Linux AMD64 可执行文件
- `config_example_user_routing.yaml` - 配置示例文件
- `USER_ROUTING_FEATURE.md` - 功能详细文档
- `README.md` - 本文件

## 技术支持

如有问题或建议，请查看 `USER_ROUTING_FEATURE.md` 获取详细文档。

## 构建信息

```
GOOS: linux
GOARCH: amd64
构建参数: -trimpath -ldflags "-s -w -buildid="
```

## 兼容性

- CentOS 7/8/9
- RHEL 7/8/9
- Ubuntu 18.04/20.04/22.04/24.04
- Debian 10/11/12
- 其他 Linux x86_64 发行版

## 原项目信息

- 官方网站: https://v2.hysteria.network/
- GitHub: https://github.com/apernet/hysteria
- 文档: https://v2.hysteria.network/zh/docs/

---

**注意**: 此版本为社区修改版，添加了用户路由功能。如需使用原版，请访问官方网站。
