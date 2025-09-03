# 🚀 Cloudflare DNS 管理工具 - 快速开始

## ⚡ 5分钟快速部署

### 🪟 Windows 用户（最简单）

1. **确保已安装 Node.js**
   - 如未安装，访问 [nodejs.org](https://nodejs.org/) 下载

2. **一键启动**
   ```
   双击运行：start-proxy-server.bat
   ```

3. **访问应用**
   - 浏览器打开：http://localhost:3001

### 🐧 Linux 用户（推荐）

1. **一键智能安装（推荐）**
   ```bash
   chmod +x simple-one-click.sh
   ./simple-one-click.sh
   ```
   *自动处理所有权限问题，语法简化，更稳定*

2. **标准安装**
   ```bash
   chmod +x install-simple.sh
   ./install-simple.sh
   ```

3. **如果仍有问题，使用自动修复安装**
   ```bash
   chmod +x auto-fix-install.sh
   ./auto-fix-install.sh
   ```

4. **访问应用**
   - 本地：http://localhost:3001
   - 远程：http://服务器IP:3001

### 🐳 Docker 用户（最稳定）

1. **一键部署**
   ```bash
   chmod +x docker-deploy.sh
   ./docker-deploy.sh
   ```

2. **或手动部署**
   ```bash
   docker-compose up -d --build
   ```

3. **访问应用**
   - http://localhost:3001

4. **Docker 管理命令**
   ```bash
   # 查看状态
   docker ps
   
   # 查看日志
   docker logs cf-dns-manager -f
   
   # 停止服务
   docker-compose down
   
   # 重新构建
   docker-compose up -d --build --force-recreate
   ```

## 🔑 配置 Cloudflare API

### 1. 获取 API Token

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. 点击 "Create Token"
3. 选择 "Custom token"
4. 设置权限：
   - **Zone** - Zone:Read
   - **Zone** - DNS:Edit
5. 选择域名范围（推荐选择特定域名）
6. 复制生成的 Token

### 2. 配置工具

1. 输入 API Token
2. 输入 Cloudflare 账户邮箱
3. 选择"代理模式"（避免 CORS 问题）
4. 点击"🔗 测试连接"
5. 点击"连接并加载域名"

## 🎯 核心功能使用

### DNS 记录管理
- **添加记录**：点击 ➕ 添加记录
- **批量添加**：点击 📦 批量添加，使用 CSV 格式
- **编辑记录**：点击记录行的 ✏️ 按钮
- **复制记录**：点击 📋 按钮，快速复制现有记录
- **删除记录**：点击 🗑️ 按钮

### 批量操作
1. **选择记录**：
   - 单选：直接点击复选框
   - 批量选：选中第1个，按住 Shift 选中第N个
   - 全选：点击表头的全选框

2. **批量操作**：
   - 点击 ⚡ 批量操作
   - 选择：开启/关闭 CDN、删除记录

### 配置迁移
1. **导出配置**：
   - 选中要导出的记录（可选）
   - 点击 📤 导出配置
   - 下载 JSON 配置文件

2. **导入配置**：
   - 点击 📥 导入配置
   - 选择配置文件
   - 选择目标域名（默认为当前域名）
   - 开始导入

## 🔧 故障排除

### CORS 错误
如果遇到跨域错误，工具会自动显示解决方案：
1. 使用代理模式（推荐）
2. 安装浏览器 CORS 扩展
3. 启动 Chrome 禁用 CORS 检查

### 权限错误
如果遇到 npm 权限错误，有多种自动修复方案：

```bash
# 方案1: 自动修复安装脚本（推荐）
chmod +x auto-fix-install.sh
./auto-fix-install.sh

# 方案2: 权限修复脚本
chmod +x fix-permissions.sh
./fix-permissions.sh

# 方案3: 手动修复
sudo chown -R $USER:$USER ~/.npm
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
```

### 启动失败
如果服务启动失败：

```bash
# 方案1: 运行诊断脚本
chmod +x diagnose.sh
./diagnose.sh

# 方案2: 使用测试服务器
cd /opt/cf-dns-manager
node test-server.js

# 方案3: 查看详细日志
sudo journalctl -u cf-dns-manager -f

# 方案4: 手动启动排查
cd /opt/cf-dns-manager
node cf-dns-proxy-server.js
```

### 连接问题
1. 检查 API Token 权限
2. 验证邮箱地址
3. 测试网络连接
4. 尝试代理模式

## 📞 技术支持

### 日志查看
- **Windows**：查看命令行输出
- **Linux**：`sudo journalctl -u cf-dns-manager -f`
- **Docker**：`docker-compose logs -f`

### 常用命令
```bash
# 重启服务
sudo systemctl restart cf-dns-manager

# 查看状态
sudo systemctl status cf-dns-manager

# 停止服务
sudo systemctl stop cf-dns-manager
```

---

**提示**：首次使用建议先阅读 README.md 了解完整功能！
