# 🌐 Cloudflare DNS 解析管理工具

专业的 DNS 记录批量管理和配置迁移工具，支持 Windows 平台，具有现代化的 Web UI 界面。

## ✨ 主要功能

- 🔑 **完整的 API 集成**：支持 Cloudflare 全套 DNS 管理 API
- 📋 **DNS 记录管理**：支持 A、AAAA、CNAME、MX、TXT、SRV、NS、PTR 等记录类型
- 📦 **批量操作**：批量添加、删除、修改 DNS 记录
- ⚡ **CDN 管理**：一键开启/关闭 Cloudflare 代理（橙色云朵）
- 📤 **配置迁移**：导出域名配置，导入到其他域名
- 🌐 **CORS 解决方案**：多种方式解决跨域访问问题

## 🚀 快速开始

### 🐧 Debian 12 部署（推荐）

#### 方法一：生产环境安装（推荐）
```bash
# 给脚本添加执行权限并运行
chmod +x install-simple.sh
./install-simple.sh
```

#### 方法二：快速测试安装
```bash
# 快速安装和测试
chmod +x quick-install.sh
./quick-install.sh
```

#### 方法三：完整功能安装
```bash
# 功能最全面的安装脚本（如果简化版本有问题）
chmod +x install-debian.sh
./install-debian.sh
```

> **⚠️ 重要提示：** 请确保在包含所有项目文件的目录中运行安装脚本！

#### 方法四：Docker 部署
```bash
# 使用 Docker Compose
docker-compose up -d

# 或者直接使用 Docker
docker build -t cf-dns-manager .
docker run -d -p 3001:3001 --name cf-dns-manager cf-dns-manager
```

### 🪟 Windows 部署

1. **安装 Node.js**（如果未安装）
   - 访问 [nodejs.org](https://nodejs.org/) 下载安装

2. **启动代理服务器**
   ```bash
   # 双击运行批处理文件
   start-proxy-server.bat
   
   # 或者手动运行
   npm install
   node cf-dns-proxy-server.js
   ```

3. **访问工具**
   - 浏览器打开：http://localhost:3001
   - 选择"代理模式"连接方式

### 方案二：浏览器扩展

1. 安装 CORS 解除扩展：
   - [CORS Unblock](https://chrome.google.com/webstore/detail/cors-unblock/lfhmikememgdcahcdlaciloancbhjino)
   - [Moesif CORS](https://chrome.google.com/webstore/detail/moesif-origin-cors-change/digfbfaphojjndkpccljibejjbppifbc)

2. 启用扩展后直接打开 `cf_dns_manager.html`

### 方案三：禁用 CORS 检查

⚠️ **仅用于开发测试，有安全风险**

```bash
# Windows
chrome.exe --disable-web-security --user-data-dir="C:\temp\chrome_dev"

# 然后打开 cf_dns_manager.html
```

## 🔧 配置说明

### API Token 设置

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. 点击 "Create Token"
3. 选择 "Custom token" 模板
4. 设置权限：
   - **Zone** - Zone:Read
   - **Zone** - DNS:Edit
5. 选择需要管理的域名范围
6. 复制生成的 Token

### 工具配置

1. 输入 API Token 和邮箱地址
2. 选择连接模式（推荐代理模式）
3. 点击"测试连接"验证配置
4. 开始管理 DNS 记录

## 📋 使用指南

### 基本操作

1. **加载域名**：配置 API 后点击"连接并加载域名"
2. **选择域名**：从列表中选择要管理的域名
3. **管理记录**：
   - 添加：点击"➕ 添加记录"
   - 编辑：点击记录右侧的"编辑"按钮
   - 删除：点击记录右侧的"删除"按钮
   - CDN：使用切换开关控制代理状态

### 批量操作

1. **批量添加**：
   ```
   格式：记录类型,名称,值,TTL,是否启用CDN
   示例：
   A,www,192.168.1.1,3600,true
   CNAME,mail,mail.example.com,3600,false
   TXT,@,"v=spf1 include:_spf.google.com ~all",3600,false
   ```

2. **批量操作**：
   - 选中多条记录
   - 使用"批量操作"按钮进行批量 CDN 开关或删除

### 配置迁移

1. **导出配置**：
   - 选择源域名
   - 点击"📤 导出配置"
   - 保存 JSON 配置文件

2. **导入配置**：
   - 点击"📥 导入配置"
   - 选择配置文件和目标域名
   - 选择是否替换现有记录

## 🔍 故障排除

### CORS 错误

如果遇到 CORS 错误，工具会自动显示解决方案提示。推荐使用代理服务器模式。

### API 错误

工具内置了详细的错误诊断系统：
- 点击错误消息中的"查看详情"按钮
- 查看具体错误代码和解决方案
- 复制错误信息用于技术支持

### 网络问题

1. 检查网络连接
2. 尝试使用代理模式
3. 检查防火墙设置
4. 确认 DNS 解析正常

## 🐧 Debian 12 详细部署指南

### 系统要求
- Debian 12 (bookworm) 或更新版本
- 至少 512MB RAM
- 至少 1GB 可用磁盘空间
- 网络连接

### 自动安装功能
自动安装脚本 `install-debian.sh` 包含以下功能：
- ✅ 系统环境检查
- ✅ 自动安装 Node.js LTS 版本
- ✅ 创建应用目录 `/opt/cf-dns-manager`
- ✅ 配置 systemd 服务
- ✅ 防火墙配置提醒
- ✅ 自动启动服务

### 手动安装步骤

1. **更新系统**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **安装 Node.js**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
   sudo apt install -y nodejs
   ```

3. **创建应用目录**
   ```bash
   sudo mkdir -p /opt/cf-dns-manager
   cd /opt/cf-dns-manager
   ```

4. **复制文件并安装依赖**
   ```bash
   # 复制所有文件到 /opt/cf-dns-manager
   sudo npm install
   ```

5. **配置 systemd 服务**
   ```bash
   sudo cp cf-dns-manager.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable cf-dns-manager
   sudo systemctl start cf-dns-manager
   ```

6. **检查服务状态**
   ```bash
   sudo systemctl status cf-dns-manager
   ```

### 服务管理

```bash
# 启动服务
sudo systemctl start cf-dns-manager

# 停止服务
sudo systemctl stop cf-dns-manager

# 重启服务
sudo systemctl restart cf-dns-manager

# 查看服务状态
sudo systemctl status cf-dns-manager

# 查看实时日志
sudo journalctl -u cf-dns-manager -f

# 查看服务日志
sudo journalctl -u cf-dns-manager --no-pager -l
```

### Nginx 反向代理配置

1. **安装 Nginx**
   ```bash
   sudo apt install nginx
   ```

2. **配置站点**
   ```bash
   sudo cp nginx-cf-dns.conf /etc/nginx/sites-available/cf-dns-manager
   sudo ln -s /etc/nginx/sites-available/cf-dns-manager /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **SSL 证书（Let's Encrypt）**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

### Docker 部署

1. **安装 Docker 和 Docker Compose**
   ```bash
   sudo apt install docker.io docker-compose
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

2. **使用 Docker Compose**
   ```bash
   # 启动服务
   docker-compose up -d
   
   # 查看日志
   docker-compose logs -f
   
   # 停止服务
   docker-compose down
   ```

### 防火墙配置

```bash
# 使用 ufw
sudo ufw allow 3001/tcp
sudo ufw enable

# 或使用 iptables
sudo iptables -A INPUT -p tcp --dport 3001 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

## 📁 文件说明

### 核心文件
- `cf_dns_manager.html` - 主要的 Web 应用程序
- `cf-dns-proxy-server.js` - CORS 代理服务器
- `package.json` - Node.js 依赖配置

### Windows 部署
- `start-proxy-server.bat` - Windows 启动脚本

### Debian/Linux 部署
- `install-debian.sh` - Debian 自动安装脚本
- `quick-install.sh` - 快速安装脚本
- `cf-dns-manager.service` - systemd 服务配置

### Nginx 和 Docker
- `nginx-cf-dns.conf` - Nginx 反向代理配置
- `Dockerfile` - Docker 镜像配置
- `docker-compose.yml` - Docker Compose 配置

### 文档
- `README.md` - 使用说明文档

## 🛡️ 安全说明

- API Token 仅存储在浏览器本地，不会上传到任何服务器
- 代理服务器仅转发请求，不存储任何数据
- 建议使用最小权限原则配置 API Token
- 生产环境中请使用 HTTPS

## 📞 技术支持

如果遇到问题：
1. 查看浏览器控制台错误信息
2. 使用工具内置的错误诊断功能
3. 检查 API Token 权限设置
4. 尝试不同的 CORS 解决方案

## 📄 许可证

MIT License - 可自由使用、修改和分发。
