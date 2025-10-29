# User-Based Routing Feature

## 概述

此功能允许根据认证用户将流量路由到不同的 outbound。当不同用户需要使用不同的代理路径时非常有用。

## 配置方法

在 `outbounds` 配置中为每个 outbound 添加 `bindUser` 字段:

```yaml
outbounds:
  - name: user1-outbound
    type: direct
    bindUser: user1
    direct:
      mode: auto

  - name: user2-outbound
    type: socks5
    bindUser: user2
    socks5:
      addr: 127.0.0.1:1080

  - name: default
    type: direct
    direct:
      mode: auto
```

## 工作原理

1. **用户认证**: 用户通过配置的认证方式(userpass, password, http, command)登录
2. **用户标识**: 认证成功后,系统获得用户的 ID (userID)
3. **路由选择**:
   - 如果用户的 ID 与某个 outbound 的 `bindUser` 匹配(不区分大小写),使用该 outbound
   - 如果没有匹配的 outbound,使用名为 "default" 的 outbound
   - 如果没有 "default",使用第一个 outbound
4. **流量转发**: 所有该用户的 TCP 和 UDP 流量都通过选定的 outbound 转发

## 与 ACL 的关系

- User-based routing 和 ACL 可以同时使用
- 路由顺序: `用户路由 -> ACL -> 实际 Outbound`
- 即: 先根据用户选择 outbound,然后在该 outbound 上应用 ACL 规则

## 配置示例

### 示例1: 基本用户路由

```yaml
auth:
  type: userpass
  userpass:
    alice: pass1
    bob: pass2

outbounds:
  - name: alice-direct
    type: direct
    bindUser: alice

  - name: bob-proxy
    type: socks5
    bindUser: bob
    socks5:
      addr: proxy.example.com:1080

  - name: default
    type: direct
```

结果:
- alice 的流量直连
- bob 的流量通过 SOCKS5 代理
- 其他用户直连

### 示例2: 与 ACL 结合

```yaml
auth:
  type: userpass
  userpass:
    premium: pass1
    free: pass2

outbounds:
  - name: premium-fast
    type: direct
    bindUser: premium
    direct:
      bindIPv4: 10.0.0.100  # 专用 IP

  - name: default
    type: direct

acl:
  inline:
    - reject(geoip:cn)
    - direct(all)
```

结果:
- premium 用户使用专用 IP,并应用 ACL 规则
- free 用户使用默认路由,同样应用 ACL 规则

## 支持的认证类型

所有认证方式都支持此功能:
- `password`: 所有用户使用同一密码,userID 固定为 "user"
- `userpass`: 每个用户有独立的用户名和密码,userID 为用户名
- `http`: 通过 HTTP API 认证,userID 由 API 返回
- `command`: 通过命令行认证,userID 由命令输出

## 支持的 Outbound 类型

所有 outbound 类型都支持:
- `direct`: 直连
- `socks5`: SOCKS5 代理
- `http`: HTTP 代理

## 实现细节

### 架构

```
Client Request
    ↓
Authentication (get userID)
    ↓
User Router (select outbound by userID)
    ↓
ACL Engine (if configured)
    ↓
Resolver (if configured)
    ↓
Actual Outbound
    ↓
Target Server
```

### 匹配规则

- `bindUser` 字段不区分大小写
- 如果 `bindUser` 为空字符串,该 outbound 不参与用户路由
- 如果多个 outbound 有相同的 `bindUser`,使用第一个匹配的

## 注意事项

1. **性能**: 用户路由是轻量级的,对性能影响极小
2. **安全性**: 确保认证配置正确,避免未授权访问
3. **默认路由**: 建议始终配置一个名为 "default" 的 outbound 作为后备
4. **大小写**: userID 匹配不区分大小写,`Alice` 和 `alice` 视为相同

## 疑难解答

### 用户总是使用默认 outbound

检查:
1. `bindUser` 字段拼写是否正确
2. 用户名是否与认证配置中的一致
3. 查看日志确认 userID 的实际值

### 某些用户无法连接

检查:
1. 对应的 outbound 配置是否正确
2. 如果使用 SOCKS5/HTTP 代理,确认代理服务器可访问
3. 查看服务器日志了解详细错误信息
