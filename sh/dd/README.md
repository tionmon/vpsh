# 一键系统重装脚本

基于 [bin456789/reinstall](https://github.com/bin456789/reinstall) 项目的一键系统重装脚本集合。

## 脚本说明

### 1. reinstall_onekey.sh - 交互式重装脚本

功能完整的交互式重装脚本，支持43种不同的Linux发行版。

**使用方法:**
```bash
# 下载并运行
curl -O https://raw.githubusercontent.com/your-repo/vpsh-2/main/dd/reinstall_onekey.sh
chmod +x reinstall_onekey.sh
sudo ./reinstall_onekey.sh
```

**支持的系统:**
- Debian (9, 10, 11, 12)
- Ubuntu (16.04, 18.04, 20.04, 22.04, 24.04, 25.04)
- CentOS (9, 10)
- Rocky Linux (8, 9, 10)
- AlmaLinux (8, 9, 10)
- Oracle Linux (8, 9)
- Fedora (41, 42)
- OpenSUSE (15.6, Tumbleweed)
- Alpine (3.19, 3.20, 3.21, 3.22)
- Anolis (7, 8, 23)
- OpenCloudOS (8, 9, 23)
- OpenEuler (20.03, 22.03, 24.03, 25.03)
- NixOS (25.05)
- Kali Linux
- Arch Linux
- Gentoo
- AOSC OS
- Fedora CoreOS

### 2. quick_install.sh - 快速重装脚本

简化版脚本，支持命令行参数，默认安装 Debian 12。

**使用方法:**
```bash
# 默认安装 Debian 12，密码为 password
bash quick_install.sh

# 指定系统和版本
bash quick_install.sh ubuntu 22.04

# 指定系统、版本和密码
bash quick_install.sh debian 12 mypassword
```

### 3. 原始命令 (1.md)

最简单的一行命令重装：
```bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh $_ && bash reinstall.sh debian 12 --password password && reboot
```

## 注意事项

⚠️ **重要警告:**
- 此脚本会完全重装系统，**所有数据将被清除**
- 请在执行前备份重要数据
- 确保网络连接稳定
- 建议在VPS或测试环境中使用

## 系统要求

- 需要root权限
- 系统需要支持curl或wget
- 需要稳定的网络连接

## 常见问题

**Q: 脚本执行失败怎么办？**
A: 检查网络连接，确保能访问GitHub，或尝试使用代理。

**Q: 支持哪些架构？**
A: 支持 x86_64 和 ARM64 架构，具体支持情况请参考原项目说明。

**Q: 重装后如何连接？**
A: 使用设置的root密码通过SSH连接，默认密码为 `password`。

## 许可证

本脚本基于原项目 [bin456789/reinstall](https://github.com/bin456789/reinstall) 开发。

## 贡献

欢迎提交Issue和Pull Request来改进这些脚本。