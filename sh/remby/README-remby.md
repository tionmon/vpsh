# Remby.sh - Caddy 反向代理自动配置脚本

## 脚本简介

`remby.sh` 是一个用于自动安装和配置 Caddy 反向代理服务器的 Bash 脚本。该脚本可以帮助用户快速部署反向代理服务，支持域名和端口号配置，并自动处理 CORS 跨域问题。

## 功能特性

- ✅ 自动检测并安装 Caddy 服务器
- ✅ 支持域名和端口号两种配置方式
- ✅ 自动配置反向代理规则
- ✅ 内置 CORS 跨域支持
- ✅ 自动启用并重启 Caddy 服务
- ✅ 友好的交互式配置界面

## 系统要求

- 操作系统：Ubuntu/Debian 系列 Linux 发行版
- 权限：需要 sudo 管理员权限
- 网络：需要互联网连接以下载 Caddy

## 安装使用

### 1. 下载脚本

```bash
wget https://raw.githubusercontent.com/your-repo/vpsh-4/main/run/remby.sh
# 或者
curl -O https://raw.githubusercontent.com/your-repo/vpsh-4/main/run/remby.sh
```

### 2. 添加执行权限

```bash
chmod +x remby.sh
```

### 3. 运行脚本

```bash
./remby.sh
```

## 使用步骤

### 步骤 1：运行脚本
执行脚本后，如果系统未安装 Caddy，脚本会自动进行安装。

### 步骤 2：输入域名或端口
脚本会提示输入域名或本地端口号：

**域名示例：**
```
请输入你的域名或本地端口号: example.com
```

**端口示例：**
```
请输入你的域名或本地端口号: 8080
```

> 注意：如果输入纯数字，脚本会自动在前面添加冒号（如 `8080` 变为 `:8080`）

### 步骤 3：输入反代地址
输入要反向代理的目标服务器地址：

```
输入反代地址 ip:port: 127.0.0.1:3000
```

### 步骤 4：完成配置
脚本会自动生成 Caddy 配置文件并重启服务。

## 配置示例

### 示例 1：域名反向代理
- 输入域名：`api.example.com`
- 反代地址：`127.0.0.1:3000`
- 结果：访问 `https://api.example.com` 会代理到本地 3000 端口

### 示例 2：端口反向代理
- 输入端口：`8080`
- 反代地址：`192.168.1.100:9000`
- 结果：访问 `http://your-server:8080` 会代理到 192.168.1.100:9000

## 生成的配置文件

脚本会在 `/etc/caddy/Caddyfile` 生成如下格式的配置：

```caddy
example.com {
    reverse_proxy 127.0.0.1:3000 {
        header_up Host {upstream_hostport}
    }

    @cors_preflight {
        method OPTIONS
        header Origin *
    }

    handle @cors_preflight {
        respond 204
        header Access-Control-Allow-Origin "*"
        header Access-Control-Allow-Methods "GET, POST, OPTIONS"
        header Access-Control-Allow-Headers "*"
    }

    header {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, OPTIONS"
    }
}
```

## 常见问题

### Q: 脚本执行失败怎么办？
A: 请确保：
- 具有 sudo 权限
- 网络连接正常
- 系统为 Ubuntu/Debian

### Q: 如何修改配置？
A: 重新运行脚本即可覆盖原有配置，或手动编辑 `/etc/caddy/Caddyfile`

### Q: 如何查看 Caddy 状态？
A: 使用以下命令：
```bash
sudo systemctl status caddy
sudo systemctl restart caddy
sudo journalctl -u caddy -f
```

### Q: 支持 HTTPS 吗？
A: 是的，Caddy 会自动为域名申请和续期 Let's Encrypt SSL 证书

## 注意事项

1. **防火墙设置**：确保目标端口（80、443）在防火墙中开放
2. **域名解析**：使用域名时，请确保 DNS 解析指向服务器 IP
3. **服务状态**：配置完成后建议检查 Caddy 服务状态
4. **备份配置**：重要配置建议备份 `/etc/caddy/Caddyfile`

## 卸载

如需卸载 Caddy：

```bash
sudo systemctl stop caddy
sudo systemctl disable caddy
sudo apt remove caddy
sudo rm -rf /etc/caddy
```

## 技术支持

如遇问题，请检查：
- Caddy 服务状态：`sudo systemctl status caddy`
- 配置文件语法：`caddy validate --config /etc/caddy/Caddyfile`
- 服务日志：`sudo journalctl -u caddy -n 50`

---

**作者**：VPSH-4 项目组  
**版本**：1.0  
**更新时间**：2024年