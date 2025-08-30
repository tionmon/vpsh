# Rsync 备份工具

基于原系统快照备份工具改进的增强版 rsync 备份解决方案，提供完整的自动化备份、监控和通知功能。

## 🚀 主要特性

### 核心备份功能
- **智能 rsync 备份**: 支持增量备份，显著节省存储空间和传输时间
- **多目录备份**: 可同时备份多个源目录（如 `/etc`, `/home`, `/var/www`, `/opt`）
- **灵活排除规则**: 支持自定义排除模式，避免备份不必要的文件
- **压缩传输**: 可选启用压缩传输，减少网络带宽占用
- **带宽限制**: 支持设置 rsync 传输带宽限制

### 自动化与调度
- **systemd 定时器**: 使用现代化的 systemd timer 替代传统 cron
- **灵活调度**: 支持按小时设置备份间隔（1-168小时）
- **随机延迟**: 避免多台服务器同时备份造成网络拥堵

### 监控与通知
- **Telegram 集成**: 实时备份状态通知
- **系统监控**: 监控 CPU 负载、内存使用率、磁盘空间
- **智能通知**: 只有在系统资源异常时才显示详细状态信息
- **详细统计**: 备份大小、传输速度、耗时统计

### 安全与可靠性
- **SSH 密钥认证**: 自动生成和配置 Ed25519 SSH 密钥
- **重试机制**: 网络操作失败时自动重试
- **进程锁**: 防止多个备份任务同时运行
- **错误处理**: 完善的错误检测和处理机制

### 存储管理
- **双重保留策略**: 分别管理本地和远程备份保留时间
- **自动清理**: 定期清理过期备份，防止磁盘空间耗尽
- **硬链接优化**: 增量备份使用硬链接，节省存储空间

## 📋 系统要求

- **操作系统**: Ubuntu/Debian Linux
- **权限**: 需要 root 权限
- **网络**: 能够访问 Telegram API 和远程服务器
- **依赖**: rsync, ssh, curl, bc, jq（安装脚本会自动安装）

## 🛠️ 安装步骤

### 1. 下载安装脚本
```bash
wget https://your-server.com/rsync_backup_installer.sh
# 或
curl -O https://your-server.com/rsync_backup_installer.sh
```

### 2. 设置执行权限
```bash
chmod +x rsync_backup_installer.sh
```

### 3. 运行安装脚本
```bash
sudo ./rsync_backup_installer.sh
```

### 4. 按照向导进行配置
安装脚本将引导您完成以下配置：
- Telegram Bot Token 和 Chat ID
- 远程服务器连接信息
- 备份源目录和排除规则
- 备份保留策略
- 定时执行设置

## ⚙️ 配置说明

### 预设配置（可在脚本顶部修改）
```bash
# Telegram 配置
BOT_TOKEN=""                    # Telegram Bot Token
CHAT_ID=""                     # Telegram Chat ID

# 远程服务器配置
TARGET_IP=""                   # 远程服务器IP
TARGET_USER=""                 # 远程用户名
SSH_PORT="22"                  # SSH端口

# 备份配置
BACKUP_SOURCE_DIRS="/etc /home /var/www /opt"  # 备份源目录
BACKUP_EXCLUDE_PATTERNS="*.log *.tmp cache/*"  # 排除模式
ENABLE_COMPRESSION="Y"          # 启用压缩传输
INCREMENTAL_BACKUP="Y"          # 启用增量备份

# 保留策略
LOCAL_BACKUP_KEEP_DAYS="7"      # 本地保留天数
REMOTE_BACKUP_KEEP_DAYS="30"    # 远程保留天数

# 执行间隔
BACKUP_INTERVAL_HOURS="24"      # 备份间隔（小时）
```

### 目录结构
```
/backups/rsync/
├── current/          # 当前备份（软链接）
└── history/          # 历史备份
    ├── 20241201_120000/
    ├── 20241202_120000/
    └── ...

远程服务器:
/backups/hostname/
├── current/          # 当前备份
├── history/          # 历史备份
└── logs/            # 日志文件
```

## 📱 Telegram 机器人设置

### 1. 创建 Telegram 机器人
1. 在 Telegram 中找到 `@BotFather`
2. 发送 `/newbot` 创建新机器人
3. 按提示设置机器人名称
4. 获取 Bot Token

### 2. 获取 Chat ID
1. 将机器人添加到群组或私聊
2. 发送任意消息给机器人
3. 访问: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
4. 在返回的 JSON 中找到 `chat.id`

## 🎛️ 管理命令

### 定时任务管理
```bash
# 查看定时任务状态
sudo systemctl status rsync-backup.timer

# 立即执行备份
sudo systemctl start rsync-backup.service

# 停止定时任务
sudo systemctl stop rsync-backup.timer

# 禁用定时任务
sudo systemctl disable rsync-backup.timer

# 启用定时任务
sudo systemctl enable rsync-backup.timer

# 查看执行日志
sudo journalctl -u rsync-backup.service -f
```

### 手动执行
```bash
# 直接运行备份脚本
sudo /usr/local/sbin/rsync_backup.sh
```

### 查看日志
```bash
# 备份日志
sudo tail -f /var/log/rsync_backup/backup.log

# 调试日志
sudo tail -f /var/log/rsync_backup/debug.log

# 安装日志
sudo cat /var/log/rsync_backup/install.log
```

## 📊 监控指标

### 系统状态监控
- **CPU 负载**: 当负载超过 `CPU核心数 × 1.5` 时在通知中显示
- **内存使用率**: 当使用率超过 80% 时在通知中显示
- **磁盘空间**: 当使用率超过 85% 时停止备份并发送警告

### 备份统计
- 当前备份大小
- 本地/远程备份数量
- 本地/远程总占用空间
- 传输速度和耗时

## 🔧 高级配置

### 修改配置
编辑配置文件：
```bash
sudo nano /etc/rsync_backup/config.conf
```

修改后手动运行一次脚本以更新定时器：
```bash
sudo /usr/local/sbin/rsync_backup.sh
```

### 自定义排除规则
在配置文件中修改 `BACKUP_EXCLUDE_PATTERNS`：
```bash
BACKUP_EXCLUDE_PATTERNS="*.log *.tmp cache/* temp/* .cache/* node_modules/* *.iso"
```

### 带宽限制
设置 rsync 传输带宽限制（KB/s）：
```bash
RSYNC_BANDWIDTH_LIMIT="1000"  # 限制为 1MB/s
```

## 🚨 故障排除

### 常见问题

1. **SSH 连接失败**
   - 检查 SSH 密钥是否正确添加到远程服务器
   - 验证远程服务器 IP、端口、用户名是否正确
   - 确认远程服务器 SSH 服务正常运行

2. **Telegram 通知失败**
   - 验证 Bot Token 和 Chat ID 是否正确
   - 检查网络是否能访问 Telegram API
   - 确认机器人已被添加到对应的聊天中

3. **磁盘空间不足**
   - 调整本地备份保留策略
   - 检查排除规则是否合理
   - 考虑增加磁盘容量或使用外部存储

4. **备份速度慢**
   - 启用压缩传输（如果网络带宽有限）
   - 设置合理的带宽限制
   - 检查网络连接质量

### 日志分析
```bash
# 查看最近的错误
sudo grep ERROR /var/log/rsync_backup/backup.log | tail -10

# 查看备份统计
sudo grep "备份完成" /var/log/rsync_backup/backup.log | tail -5

# 监控实时日志
sudo tail -f /var/log/rsync_backup/backup.log
```

## 📈 性能优化

### 网络优化
- 在低峰期执行备份
- 使用压缩传输节省带宽
- 设置合理的带宽限制

### 存储优化
- 定期清理不需要的文件
- 使用增量备份减少传输量
- 合理设置保留策略

### 系统资源
- 避免在系统负载高时执行备份
- 监控内存使用情况
- 确保有足够的磁盘空间

## 📄 许可证

本项目基于原系统快照备份工具改进，继承其开源精神。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个工具！

---

**注意**: 请在生产环境使用前充分测试，并确保有完整的备份策略。
