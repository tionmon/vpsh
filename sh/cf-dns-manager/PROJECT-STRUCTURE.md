# 🌐 Cloudflare DNS 解析管理工具 - 项目文件结构

## 📁 项目文件总览

```
cf-dns-manager-final/
├── 📄 核心文件
│   ├── cf_dns_manager.html          # 主要的 Web 应用程序 (99KB)
│   ├── cf-dns-proxy-server.js       # CORS 代理服务器 (3KB)
│   └── package.json                 # Node.js 依赖配置 (726B)
│
├── 🪟 Windows 部署
│   └── start-proxy-server.bat       # Windows 一键启动脚本 (1KB)
│
├── 🐧 Linux/Debian 部署
│   ├── one-click-install.sh         # 一键智能安装脚本 (推荐) (8KB)
│   ├── install-simple.sh            # 生产环境安装脚本 (6KB)
│   ├── auto-fix-install.sh          # 自动修复安装脚本 (4KB)
│   ├── install-debian.sh            # 完整功能安装脚本 (10KB)
│   ├── quick-install.sh             # 快速测试脚本 (2KB)
│   ├── manual-install.sh            # 手动安装脚本 (3KB)
│   ├── fix-permissions.sh           # npm 权限修复脚本 (1KB)
│   └── cf-dns-manager.service       # systemd 服务配置 (827B)
│
├── 🐳 容器化部署
│   ├── Dockerfile                   # Docker 镜像配置 (824B)
│   └── docker-compose.yml           # Docker Compose 配置 (1KB)
│
├── 🌐 反向代理
│   └── nginx-cf-dns.conf           # Nginx 反向代理配置 (3KB)
│
└── 📚 文档
    ├── README.md                    # 主要使用说明 (8KB)
    ├── INSTALL-DEBIAN.md           # Debian 详细安装指南 (6KB)
    └── PROJECT-STRUCTURE.md        # 本文件 - 项目结构说明
```

## 🚀 快速开始指南

### Windows 用户
```bash
# 双击运行
start-proxy-server.bat
```

### Debian/Ubuntu 用户
```bash
# 一键智能安装（推荐）
chmod +x one-click-install.sh
./one-click-install.sh

# 或生产环境部署
chmod +x install-simple.sh
./install-simple.sh

# 或快速测试
chmod +x quick-install.sh
./quick-install.sh
```

### Docker 用户
```bash
# 一键部署
docker-compose up -d
```

## 📋 文件详细说明

### 核心应用文件

#### `cf_dns_manager.html` (99KB)
- **功能**：主要的 Web 应用程序界面
- **特性**：
  - 现代化的响应式 UI 设计
  - 完整的 Cloudflare API 集成
  - 支持所有 DNS 记录类型 (A/AAAA/CNAME/MX/TXT/SRV/NS/PTR)
  - 批量操作功能（添加、删除、CDN 开关）
  - 智能搜索和筛选
  - Shift 批量选择
  - 记录复制功能
  - 配置导出/导入
  - 详细错误处理和 CORS 解决方案

#### `cf-dns-proxy-server.js` (3KB)
- **功能**：解决浏览器 CORS 跨域限制的代理服务器
- **特性**：
  - Express.js 服务器
  - 完整的 CORS 头部支持
  - 请求日志和错误处理
  - 健康检查端点
  - 静态文件服务

#### `package.json` (726B)
- **功能**：Node.js 项目依赖配置
- **依赖**：
  - express: Web 服务器框架
  - http-proxy-middleware: HTTP 代理中间件
  - cors: CORS 支持库

### 部署脚本

#### Windows 部署
- **`start-proxy-server.bat`**：Windows 一键启动脚本
  - 自动检测 Node.js
  - 自动安装依赖
  - 启动代理服务器

#### Linux/Debian 部署
- **`install-simple.sh`** (推荐)：生产环境安装
  - 系统环境检查
  - 自动安装 Node.js
  - 创建 systemd 服务
  - 防火墙配置提醒

- **`install-debian.sh`**：功能最全面的安装脚本
  - 完整的系统检查
  - 彩色输出和详细日志
  - 用户权限管理

- **`quick-install.sh`**：快速测试安装
  - 最简化的安装流程
  - 前台运行，便于调试

- **`manual-install.sh`**：手动安装选项
  - 提供多种安装方案
  - 权限问题自动处理

- **`fix-permissions.sh`**：修复 npm 权限问题
  - 配置用户级 npm 目录
  - 解决 EACCES 错误

#### 系统服务
- **`cf-dns-manager.service`**：systemd 服务配置
  - 自动启动
  - 日志管理
  - 安全设置

### 容器化部署

#### `Dockerfile` (824B)
- **功能**：Docker 镜像构建配置
- **特性**：
  - 基于 Node.js 18 Alpine
  - 非 root 用户运行
  - 健康检查
  - 安全设置

#### `docker-compose.yml` (1KB)
- **功能**：Docker Compose 编排配置
- **特性**：
  - 自动重启
  - 健康检查
  - 网络配置
  - 可选 Nginx 反向代理

### 反向代理

#### `nginx-cf-dns.conf` (3KB)
- **功能**：Nginx 反向代理配置
- **特性**：
  - SSL/HTTPS 支持
  - 安全头部设置
  - 静态文件缓存
  - CORS 支持

### 文档

#### `README.md` (8KB)
- **内容**：主要使用说明文档
- **包含**：
  - 功能介绍
  - 快速开始指南
  - 配置说明
  - 故障排除

#### `INSTALL-DEBIAN.md` (6KB)
- **内容**：Debian 详细安装指南
- **包含**：
  - 系统要求
  - 安装步骤
  - 服务管理
  - 故障排除

## 🎯 使用建议

### 开发/测试环境
1. Windows：使用 `start-proxy-server.bat`
2. Linux：使用 `quick-install.sh`

### 生产环境
1. Debian/Ubuntu：使用 `install-simple.sh`
2. 容器化：使用 `docker-compose.yml`
3. 反向代理：配置 `nginx-cf-dns.conf`

### 故障排除
1. 权限问题：运行 `fix-permissions.sh`
2. 手动安装：使用 `manual-install.sh`
3. 查看文档：阅读 `INSTALL-DEBIAN.md`

## 📊 项目统计

- **总文件数**：16 个
- **总大小**：约 150KB
- **代码行数**：约 2500+ 行
- **支持平台**：Windows、Linux、Docker
- **支持架构**：x86_64、ARM64

## 🔧 维护说明

### 备份重要文件
- `cf_dns_manager.html` - 主程序
- `cf-dns-proxy-server.js` - 代理服务器
- `package.json` - 依赖配置

### 更新流程
1. 备份当前版本
2. 替换核心文件
3. 更新依赖 (`npm install`)
4. 重启服务

### 自定义配置
- 修改端口：编辑 `cf-dns-proxy-server.js`
- 修改服务：编辑 `cf-dns-manager.service`
- 修改代理：编辑 `nginx-cf-dns.conf`

---

**版本**：v1.0 Final  
**创建日期**：2024年  
**许可证**：MIT License
