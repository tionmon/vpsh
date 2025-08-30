# 🚀 快速入门指南

## 📋 准备工作

### 1. 系统要求
- Ubuntu/Debian Linux 系统
- Root 权限
- 网络连接（访问 Telegram API 和远程服务器）

### 2. 准备 Telegram 机器人
```bash
# 1. 在 Telegram 中找到 @BotFather
# 2. 发送 /newbot 创建机器人
# 3. 记录 Bot Token（格式：1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg）

# 4. 获取 Chat ID
# 方法1：将机器人添加到群组，发送消息后访问：
# https://api.telegram.org/bot<BOT_TOKEN>/getUpdates

# 方法2：私聊机器人，发送消息后访问上述链接
```

### 3. 准备远程备份服务器
```bash
# 在远程服务器上创建备份用户
sudo useradd -m -s /bin/bash backup
sudo mkdir -p /backups
sudo chown backup:backup /backups
sudo chmod 755 /backups
```

## ⚡ 快速安装

### 方法1：交互式安装（推荐新手）
```bash
# 1. 下载安装脚本
wget https://raw.githubusercontent.com/your-repo/rsync-backup-tool/main/rsync_backup_installer.sh

# 2. 运行安装脚本
sudo bash rsync_backup_installer.sh

# 3. 按照提示输入配置信息
```

### 方法2：快速部署（推荐批量部署）
```bash
# 1. 下载快速部署脚本
wget https://raw.githubusercontent.com/your-repo/rsync-backup-tool/main/quick_deploy.sh

# 2. 编辑脚本顶部的配置变量
nano quick_deploy.sh

# 3. 运行部署
sudo bash quick_deploy.sh
```

### 方法3：预配置安装
```bash
# 1. 下载安装脚本
wget https://raw.githubusercontent.com/your-repo/rsync-backup-tool/main/rsync_backup_installer.sh

# 2. 编辑脚本顶部的配置区域
nano rsync_backup_installer.sh

# 3. 修改以下变量：
BOT_TOKEN="你的机器人Token"
CHAT_ID="你的ChatID"
TARGET_IP="远程服务器IP"
TARGET_USER="backup"
# ... 其他配置

# 4. 运行安装
sudo bash rsync_backup_installer.sh
```

## 🔧 基础配置示例

### 最小化配置
```bash
# Telegram
BOT_TOKEN="1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg"
CHAT_ID="-1001234567890"

# 远程服务器
TARGET_IP="192.168.1.100"
TARGET_USER="backup"

# 备份源（默认即可）
BACKUP_SOURCE_DIRS="/etc /home /var/www"
```

### 生产环境配置
```bash
# 完整配置
BOT_TOKEN="你的Token"
CHAT_ID="你的ChatID"
TARGET_IP="备份服务器IP"
TARGET_USER="backup"
SSH_PORT="22"
TARGET_BASE_DIR="/backups"
BACKUP_SOURCE_DIRS="/etc /home /var/www /opt /usr/local"
BACKUP_EXCLUDE_PATTERNS="*.log *.tmp cache/* temp/* node_modules/*"
LOCAL_BACKUP_KEEP_DAYS="7"
REMOTE_BACKUP_KEEP_DAYS="30"
BACKUP_INTERVAL_HOURS="12"
ENABLE_COMPRESSION="Y"
INCREMENTAL_BACKUP="Y"
```

## ✅ 验证安装

### 1. 检查定时任务
```bash
sudo systemctl status rsync-backup.timer
sudo systemctl list-timers | grep rsync
```

### 2. 手动执行测试
```bash
sudo systemctl start rsync-backup.service
```

### 3. 查看日志
```bash
sudo journalctl -u rsync-backup.service -f
sudo tail -f /var/log/rsync_backup/backup.log
```

### 4. 检查备份文件
```bash
ls -la /backups/rsync/
ls -la /backups/rsync/current/
ls -la /backups/rsync/history/
```

## 📱 Telegram 通知示例

成功安装后，您将收到类似的通知：

```
🚀 Rsync备份工具安装测试
- 您正在使用Rsync备份工具
- 时间: 2024-12-01 15:30:25
- 主机: web-server-01
- 备份源: /etc, /home, /var/www, /opt

⏰ 定时任务更新 | web-server-01
- 频率: 30分钟后首次运行，之后每24小时一次
- 下次运行: 2024年12月01日 16:00 (CST)

✅ Rsync备份操作完成 | web-server-01
- 当前备份大小: 2.3GB
- 本地备份数量: 3个
- 本地总大小: 6.8GB
- 磁盘使用率: 45%
- 远程备份数量: 3个
- 远程总大小: 6.8GB
- 时间: 2024-12-01 16:00:15
```

## 🛠️ 常用管理命令

```bash
# 查看定时任务状态
sudo systemctl status rsync-backup.timer

# 立即执行备份
sudo systemctl start rsync-backup.service

# 停止定时任务
sudo systemctl stop rsync-backup.timer

# 重启定时任务
sudo systemctl restart rsync-backup.timer

# 查看实时日志
sudo journalctl -u rsync-backup.service -f

# 查看最近10条日志
sudo journalctl -u rsync-backup.service -n 10

# 手动运行备份脚本
sudo /usr/local/sbin/rsync_backup.sh
```

## 🔍 故障排除

### SSH 连接问题
```bash
# 测试SSH连接
ssh -p 22 backup@192.168.1.100

# 检查SSH密钥
ls -la /root/.ssh/
cat /root/.ssh/id_ed25519.pub

# 手动添加密钥到远程服务器
ssh-copy-id -p 22 backup@192.168.1.100
```

### Telegram 通知问题
```bash
# 测试Telegram API
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
     -d chat_id="<CHAT_ID>" \
     -d text="测试消息"

# 检查网络连接
ping api.telegram.org
```

### 磁盘空间问题
```bash
# 检查磁盘使用情况
df -h /backups

# 手动清理旧备份
find /backups/rsync/history -type d -mtime +7 -exec rm -rf {} \;

# 检查备份大小
du -sh /backups/rsync/*
```

## 📊 监控和维护

### 定期检查项目
- [ ] Telegram 通知是否正常
- [ ] SSH 密钥是否有效
- [ ] 磁盘空间是否充足
- [ ] 备份文件是否完整
- [ ] 远程服务器连接是否稳定

### 建议的维护周期
- **每日**：检查 Telegram 通知
- **每周**：检查磁盘使用率和备份完整性
- **每月**：测试备份恢复流程
- **每季度**：更新排除规则和保留策略

## 🚀 高级功能

### 批量部署到多台服务器
```bash
# 生成批量部署脚本
./quick_deploy.sh --batch

# 批量部署
./batch_deploy.sh 192.168.1.10 192.168.1.11 192.168.1.12
```

### 自定义备份策略
```bash
# 编辑配置文件
sudo nano /etc/rsync_backup/config.conf

# 重新加载配置（运行一次脚本）
sudo /usr/local/sbin/rsync_backup.sh
```

### 集成到监控系统
```bash
# 导出备份状态到监控系统
sudo journalctl -u rsync-backup.service --since="1 hour ago" --no-pager | \
grep -E "(备份完成|备份失败)" | tail -1
```

---

🎉 **恭喜！您已成功设置 Rsync 备份工具！**

如有问题，请查看 [完整文档](README.md) 或提交 Issue。
