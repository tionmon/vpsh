# VPS脚本合集 - 一键运行工具

基于 `【合集】常用VPS脚本.md` 创建的交互式shell脚本，提供便捷的菜单选择功能。

## 功能特点

- 🎯 **分类清晰**: 按照9大类别组织脚本
- 🖥️ **交互式菜单**: 彩色界面，操作简单
- ⚠️ **安全确认**: 执行前需要用户确认
- 📝 **详细说明**: 每个脚本都有清晰的描述

## 脚本分类

### 1. DD重装脚本
- 史上最强脚本 (Debian 12)
- 萌咖大佬的脚本 (Debian 11)
- beta.gs大佬的脚本
- DD Windows 10

### 2. 综合测试脚本
- bench.sh
- LemonBench
- 融合怪
- NodeBench

### 3. 性能测试
- YABS 完整测试
- YABS 跳过网络测试
- YABS 跳过网络和磁盘测试
- YABS GB5测试

### 4. 流媒体及IP质量测试
- 流媒体解锁检测 (常用版本)
- 原生检测脚本
- 流媒体解锁检测 (准确度最高)
- IP质量体检脚本
- 一键修改解锁DNS

### 5. 测速脚本
- Speedtest
- Taier
- Hyperspeed
- 全球测速
- 区域速度测试
- Ping和路由测试

### 6. 回程测试
- 直接显示回程 (小白推荐)
- 回程详细测试 (推荐)
- 回程测试 (备用)

### 7. 功能脚本
- 添加SWAP
- 安装Fail2ban
- 一键开启BBR
- 多功能BBR安装脚本
- 锐速/BBRPLUS/BBR2/BBR3
- TCP窗口调优
- 添加WARP
- 25端口开放测试

### 8. 一键安装常用环境及软件
- 安装Docker
- 安装Python
- 安装iperf3
- 安装realm
- 安装gost
- 安装极光面板
- 安装哪吒监控
- 安装WARP
- 安装Aria2
- 安装宝塔面板
- 安装PVE虚拟化
- 安装Argox

### 9. 综合功能脚本
- 科技lion
- SKY-BOX

## 使用方法

### 方法一：直接运行
```bash
bash vps_scripts_collection.sh
```

### 方法二：赋予执行权限后运行
```bash
chmod +x vps_scripts_collection.sh
./vps_scripts_collection.sh
```

### 方法三：一键下载并运行
```bash
wget https://raw.githubusercontent.com/your-repo/vpsh-2/main/vps_scripts_collection.sh && chmod +x vps_scripts_collection.sh && ./vps_scripts_collection.sh
```

## 注意事项

1. **权限要求**: 建议使用root权限运行，某些功能需要管理员权限
2. **网络要求**: 需要稳定的网络连接来下载和执行脚本
3. **系统兼容**: 主要适用于Linux系统 (Debian/Ubuntu/CentOS等)
4. **安全提醒**: 执行前请确认脚本来源的安全性
5. **参数修改**: 某些脚本需要手动修改参数 (如密码、端口等)

## 安全特性

- ✅ 执行前确认机制
- ✅ 彩色提示信息
- ✅ 错误处理
- ✅ 用户友好的界面

## 系统要求

- Linux操作系统
- Bash shell
- 基本的网络工具 (wget, curl)
- 建议使用root权限

## 更新日志

### v1.0 (2024)
- 初始版本发布
- 包含9大类别的VPS常用脚本
- 交互式菜单界面
- 安全确认机制

## 贡献

欢迎提交Issue和Pull Request来改进这个脚本合集。

## 免责声明

本脚本合集仅供学习和测试使用，使用者需要自行承担使用风险。请在使用前仔细阅读各个脚本的说明和要求。

---

**作者**: VPS脚本合集  
**版本**: 1.0  
**更新时间**: 2024年