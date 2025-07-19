# Debian 12 系统重置脚本

本目录包含两个用于Debian 12系统重置的脚本，可以帮助您清理系统中的各种服务和非系统文件，类似于重装系统但不需要实际重装。

## ⚠️ 重要警告

**这些脚本会删除大量数据和服务，使用前请务必：**
1. 备份所有重要数据
2. 确保您了解脚本的功能
3. 在测试环境中先行验证
4. 确保您有系统管理员权限

## 脚本说明

### 1. `debian12_reset.sh` - 完整重置脚本

这是一个全自动的系统重置脚本，会一次性执行所有清理操作。

**功能包括：**
- 完全清理Docker（容器、镜像、卷、网络）
- 删除所有Snap包和Flatpak应用
- 清理Web服务器（Apache、Nginx、Lighttpd）
- 清理数据库服务（MySQL、PostgreSQL、Redis、MongoDB）
- 删除开发工具（Node.js、Python pip、Go、Java）
- 清理虚拟化软件（VirtualBox、QEMU、libvirt）
- 清理网络服务（OpenVPN、StrongSwan、WireGuard）
- 可选清理桌面环境
- 清理用户安装的软件（/opt、/usr/local）
- 清理日志文件和缓存
- 清理用户目录缓存
- 重置网络配置
- 清理非必要的启动服务

### 2. `debian12_reset_safe.sh` - 安全重置脚本

这是一个交互式的安全版本，会在每个主要步骤前询问确认。

**特点：**
- 每个操作前都会询问确认
- 可以选择性地执行某些清理操作
- 更适合初次使用或需要保留某些服务的情况
- 降低误删重要数据的风险

## 使用方法

### 准备工作

1. 确保您有root权限或sudo权限
2. 备份重要数据
3. 为脚本添加执行权限：

```bash
chmod +x debian12_reset.sh
chmod +x debian12_reset_safe.sh
```

### 执行脚本

**推荐：先使用安全版本**
```bash
sudo ./debian12_reset_safe.sh
```

**完整重置（谨慎使用）**
```bash
sudo ./debian12_reset.sh
```

## 清理内容详细说明

### 1. Docker清理
- 停止并删除所有容器
- 删除所有镜像
- 删除所有卷和网络
- 卸载Docker服务
- 删除Docker配置目录

### 2. 包管理器清理
- **Snap**: 删除所有snap包，可选卸载snapd
- **Flatpak**: 删除所有flatpak应用
- **APT**: 清理缓存和孤立包

### 3. 服务清理
- **Web服务器**: Apache2, Nginx, Lighttpd
- **数据库**: MySQL, MariaDB, PostgreSQL, Redis, MongoDB
- **网络服务**: OpenVPN, StrongSwan, WireGuard
- **虚拟化**: VirtualBox, QEMU, libvirt

### 4. 开发环境清理
- Node.js和npm
- Python pip
- Go语言环境
- Java JDK/JRE
- 相关配置和缓存目录

### 5. 系统清理
- 日志文件（保留最近7天或1天）
- 临时文件和缓存
- 用户目录缓存（浏览器缓存、下载文件等）
- 非必要的启动服务

### 6. 网络配置重置
- 重置网络接口配置为DHCP
- 备份原配置文件

## 保留的系统服务

脚本会保留以下关键系统服务：
- SSH服务（ssh/sshd）
- 网络服务（networking）
- 系统服务（systemd-*）
- 消息总线（dbus）
- 定时任务（cron）
- 系统日志（rsyslog）
- 设备管理（udev）
- 终端服务（getty*）

## 注意事项

1. **数据丢失风险**：脚本会删除大量数据，请确保重要数据已备份

2. **网络连接**：重置后可能需要重新配置网络

3. **SSH访问**：如果通过SSH连接，重启后可能需要重新配置

4. **桌面环境**：如果清理了桌面环境，系统将变成纯命令行界面

5. **服务依赖**：某些应用可能依赖被清理的服务

## 恢复建议

重置后，您可能需要：

1. **重新安装必要软件**：
```bash
apt update
apt install curl wget git vim
```

2. **配置网络**（如果需要）：
```bash
nano /etc/network/interfaces
```

3. **重新安装开发环境**（根据需要）：
```bash
# Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
apt-get install -y nodejs

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

## 故障排除

如果脚本执行过程中出现错误：

1. 检查是否有足够的权限（使用sudo）
2. 确保系统有足够的磁盘空间
3. 检查网络连接是否正常
4. 查看具体错误信息并针对性解决

## 版本信息

- 适用系统：Debian 12 (Bookworm)
- 脚本版本：1.0
- 最后更新：2024年

## 免责声明

使用这些脚本的风险由用户自行承担。作者不对因使用这些脚本而导致的任何数据丢失或系统损坏负责。请在使用前仔细阅读脚本内容并确保您了解其功能。