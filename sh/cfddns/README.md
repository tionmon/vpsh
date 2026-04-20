# cfddns — Cloudflare DNS 定时解析工具

自动在指定时间点更改 Cloudflare DNS A 记录解析，适用于需要在不同时间段将域名指向不同 IP 的场景。

## 功能特性

- ⏰ **定时切换** — 按配置的时间点自动更新 DNS A 记录
- 🔄 **智能更新** — 记录已存在则更新，不存在则创建；IP 未变则跳过
- 🔐 **双重认证** — 支持 API Token（推荐）和 Global API Key + Email
- 📋 **多域名支持** — 同时管理多个域名的定时切换
- 🛡️ **系统服务** — 提供 systemd 服务，开机自启、自动重启
- 📝 **完整日志** — 同时输出到文件和 stdout / journalctl

## 快速开始

### 1. 上传至服务器

```bash
# 将整个 cfddns 目录上传到服务器
scp -r cfddns/ root@your-server:/tmp/
```

### 2. 一键安装

```bash
cd /tmp/cfddns
chmod +x install.sh
sudo bash install.sh
```

### 3. 配置

```bash
nano /opt/cfddns/config.yaml
```

填入 Cloudflare 认证信息和 DNS 调度规则：

```yaml
cloudflare:
  # 推荐：API Token（需要 Zone:DNS:Edit + Zone:Zone:Read 权限）
  api_token: "your_api_token_here"

schedules:
  - domain: a.test.com
    proxied: false
    ttl: 1        # 1 = 自动
    records:
      - time: "10:00"
        ip: 1.1.1.1
      - time: "11:00"
        ip: 2.2.2.2
      - time: "19:00"
        ip: 3.3.3.3
```

### 4. 测试连接

```bash
cd /opt/cfddns
venv/bin/python3 cfddns.py test
```

### 5. 启动服务

```bash
systemctl start cfddns
systemctl status cfddns
```

## 命令参考

```bash
cd /opt/cfddns

# 启动调度器（作为前台进程，通常由 systemd 调用）
venv/bin/python3 cfddns.py run

# 测试 CF 连接并显示当前 DNS 状态
venv/bin/python3 cfddns.py test

# 立即应用当前时间对应的记录
venv/bin/python3 cfddns.py now
venv/bin/python3 cfddns.py now a.test.com    # 指定域名

# 手动设置（覆盖调度，立即生效）
venv/bin/python3 cfddns.py set a.test.com 4.4.4.4

# 查看所有配置的调度
venv/bin/python3 cfddns.py status
```

## 服务管理

```bash
systemctl start cfddns       # 启动
systemctl stop cfddns        # 停止
systemctl restart cfddns     # 重启
systemctl status cfddns      # 状态
systemctl enable cfddns      # 开机自启
systemctl disable cfddns     # 取消自启
```

## 日志查看

```bash
# journalctl
journalctl -u cfddns -f              # 实时跟踪
journalctl -u cfddns --since today   # 今日日志

# 文件日志
tail -f /opt/cfddns/logs/cfddns.log
```

## Cloudflare API Token 创建

1. 访问 [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. 点击 **Create Token**
3. 使用 **Edit zone DNS** 模板，或自定义权限：
   - **Zone → DNS → Edit**
   - **Zone → Zone → Read**
4. Zone Resources 选择 **Include → Specific zone → 你的域名**
5. 复制 Token 填入 `config.yaml`

## 卸载

```bash
sudo bash /opt/cfddns/uninstall.sh
```

## 文件结构

```
cfddns/
├── cfddns.py           # 主程序
├── config.yaml         # 配置文件（示例）
├── requirements.txt    # Python 依赖
├── cfddns.service      # systemd 服务单元
├── install.sh          # 一键安装脚本
├── uninstall.sh        # 卸载脚本
└── README.md           # 本文件
```

## 工作原理

1. 启动时读取 `config.yaml`，验证格式和 CF 连接
2. 为每条调度规则注册定时任务（使用 `schedule` 库）
3. 主循环每 30 秒检查一次是否有待执行的任务
4. 到达指定时间时，通过 CF API 更新对应的 A 记录
5. 如果目标 IP 与当前一致，则跳过更新

> **注意**: 时间使用服务器本地时区。请确认服务器时区设置正确：
> ```bash
> timedatectl set-timezone Asia/Shanghai
> ```
