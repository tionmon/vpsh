# 🚀 VPSH 脚本管理面板

## 📝 简介

VPSH 是一个功能强大的脚本管理工具，为 VPS 服务器管理提供了简洁美观的命令行界面。通过这个工具，您可以轻松执行各种常用脚本和系统维护任务，无需记忆复杂的命令。

## ✨ 特性

- 🎨 美观的命令行界面，带有彩色边框和文字
- 📋 集成了20个常用脚本，一键执行
- 🔄 自动适应终端窗口大小
- 🌐 支持国内/国外不同网络环境的脚本选择
- 🛠️ 包含系统维护、网络测试、面板安装等多种功能

## 📋 可用脚本列表

| 序号 | 脚本名称 | 功能描述 |
|------|---------|---------|
| 0 | t | 快捷别名设置 |
| 1 | kejilion | 科技lion一键脚本 |
| 2 | reinstall | 系统重装工具（支持国内/国外源） |
| 3 | jpso | 流媒体解锁检测 |
| 4 | update | 系统更新与基础工具安装 |
| 5 | realm | Realm部署工具（支持国内/国外源） |
| 6 | nezha | 哪吒监控面板（支持国内/国外源） |
| 7 | xui | X-UI面板安装（支持多种版本） |
| 8 | toolbasic | 基础工具安装 |
| 9 | onekey | V2Ray WSS一键安装 |
| 10 | backtrace | 回溯工具 |
| 11 | gg_test | Google连通性测试 |
| 12 | key.sh | SSH密钥管理（支持国内/国外源） |
| 13 | jiguang | 极光面板安装 |
| 14 | NetQuality | 网络质量测试 |
| 15 | armnetwork | ARM网络配置 |
| 16 | NodeQuality | 节点质量测试 |
| 17 | snell | Snell服务器安装 |
| 18 | msdocker | 1ms Docker助手 |
| 19 | indocker | 国内Docker安装 |

## 🚀 使用方法

1. 下载脚本：
   ```bash
   wget -O vpsh.sh https://raw.githubusercontent.com/tionmon/vpsh/main/vpsh.sh
   ```

2. 添加执行权限：
   ```bash
   chmod +x vpsh.sh
   ```

3. 运行脚本：
   ```bash
   ./vpsh.sh
   ```

4. 根据界面提示选择需要执行的脚本序号

## 🔧 设置别名

您可以设置别名以便更快地访问此脚本：

```bash
alias t='./vpsh.sh'
```

将此行添加到您的 `~/.bashrc` 文件中，然后执行 `source ~/.bashrc`，之后您就可以直接使用 `t` 命令来启动脚本。

## 📜 许可证

本项目采用 MIT 许可证

## 🤝 贡献

欢迎提交问题和功能请求！