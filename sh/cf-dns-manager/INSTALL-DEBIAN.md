# Debian 12 安装指南

## 🚀 快速开始

### 准备工作

1. **确保所有文件在同一目录**
   ```bash
   ls -la
   # 应该看到以下文件：
   # - cf_dns_manager.html
   # - cf-dns-proxy-server.js
   # - package.json
   # - install-simple.sh
   # - quick-install.sh
   ```

2. **给脚本添加执行权限**
   ```bash
   chmod +x install-simple.sh
   chmod +x quick-install.sh
   ```

## 📋 安装方案

### 方案一：生产环境安装（推荐）

使用 `install-simple.sh` 脚本进行完整安装：

```bash
./install-simple.sh
```

**功能特性：**
- ✅ 自动检测系统环境和必要文件
- ✅ 安装 Node.js LTS 版本
- ✅ 创建应用目录 `/opt/cf-dns-manager`
- ✅ 配置 systemd 服务（开机自启）
- ✅ 设置正确的用户权限 (www-data)
- ✅ 防火墙配置提醒

**安装后服务管理：**
```bash
sudo systemctl start cf-dns-manager     # 启动服务
sudo systemctl stop cf-dns-manager      # 停止服务
sudo systemctl restart cf-dns-manager   # 重启服务
sudo systemctl status cf-dns-manager    # 查看状态
sudo journalctl -u cf-dns-manager -f    # 查看实时日志
```

### 方案二：快速测试安装

使用 `quick-install.sh` 脚本进行快速测试：

```bash
./quick-install.sh
```

**适用场景：**
- 快速测试功能
- 开发环境
- 临时使用

**注意：** 此方案在前台运行，按 Ctrl+C 即可停止

## 🐳 Docker 部署

如果您更喜欢使用 Docker：

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 🔧 故障排除

### 常见问题

1. **文件不存在错误**
   ```
   cp: cannot create regular file...
   ```
   **解决方案：** 确保在包含所有文件的目录中运行脚本

2. **权限不足错误**
   ```
   Permission denied
   ```
   **解决方案：** 
   ```bash
   chmod +x install-simple.sh
   sudo ./install-simple.sh
   ```

3. **npm 权限错误（EACCES）**
   ```
   npm error code EACCES
   npm error syscall mkdir
   npm error path /var/www
   ```
   **解决方案：** 
   ```bash
   # 方案1：使用权限修复脚本
   chmod +x fix-permissions.sh
   ./fix-permissions.sh
   source ~/.bashrc
   
   # 方案2：使用手动安装脚本
   chmod +x manual-install.sh
   ./manual-install.sh
   
   # 方案3：强制安装（仅测试环境）
   sudo npm install --unsafe-perm=true --allow-root
   ```

4. **端口被占用**
   ```
   Port 3001 is already in use
   ```
   **解决方案：** 
   ```bash
   # 查看占用端口的进程
   sudo netstat -tulpn | grep 3001
   # 或者使用不同端口
   PORT=3002 node cf-dns-proxy-server.js
   ```

5. **Node.js 版本过低**
   **解决方案：** 脚本会自动检测并更新 Node.js

### 手动安装步骤

如果自动脚本出现问题，可以手动安装：

```bash
# 1. 更新系统
sudo apt update

# 2. 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# 3. 创建目录
sudo mkdir -p /opt/cf-dns-manager
cd /opt/cf-dns-manager

# 4. 复制文件（从源目录）
sudo cp /path/to/your/files/* ./

# 5. 安装依赖
sudo npm install

# 6. 设置权限
sudo chown -R www-data:www-data /opt/cf-dns-manager

# 7. 创建服务
sudo cp cf-dns-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cf-dns-manager
sudo systemctl start cf-dns-manager
```

## 🌐 访问应用

安装完成后，可以通过以下地址访问：

- **本地访问：** http://localhost:3001
- **远程访问：** http://服务器IP:3001

## 🛡️ 安全配置

### 防火墙设置

```bash
# 使用 ufw
sudo ufw allow 3001/tcp
sudo ufw enable

# 使用 iptables
sudo iptables -A INPUT -p tcp --dport 3001 -j ACCEPT
```

### Nginx 反向代理（可选）

如果需要使用域名和 SSL：

```bash
# 安装 Nginx
sudo apt install nginx

# 复制配置文件
sudo cp nginx-cf-dns.conf /etc/nginx/sites-available/cf-dns-manager
sudo ln -s /etc/nginx/sites-available/cf-dns-manager /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重载配置
sudo systemctl reload nginx

# 安装 SSL 证书
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## 📊 监控和日志

### 查看服务状态
```bash
sudo systemctl status cf-dns-manager
```

### 查看日志
```bash
# 实时日志
sudo journalctl -u cf-dns-manager -f

# 最近的日志
sudo journalctl -u cf-dns-manager --since "1 hour ago"

# 错误日志
sudo journalctl -u cf-dns-manager -p err
```

### 性能监控
```bash
# 查看进程
ps aux | grep node

# 查看端口使用
sudo netstat -tulpn | grep 3001

# 查看内存使用
free -h
```

## 🔄 更新和维护

### 更新应用
```bash
# 停止服务
sudo systemctl stop cf-dns-manager

# 备份当前版本
sudo cp -r /opt/cf-dns-manager /opt/cf-dns-manager.backup

# 复制新文件
sudo cp new-files/* /opt/cf-dns-manager/

# 更新依赖
cd /opt/cf-dns-manager
sudo npm install

# 启动服务
sudo systemctl start cf-dns-manager
```

### 卸载应用
```bash
# 停止并禁用服务
sudo systemctl stop cf-dns-manager
sudo systemctl disable cf-dns-manager

# 删除服务文件
sudo rm /etc/systemd/system/cf-dns-manager.service
sudo systemctl daemon-reload

# 删除应用目录
sudo rm -rf /opt/cf-dns-manager

# 删除防火墙规则（可选）
sudo ufw delete allow 3001/tcp
```

## 📞 技术支持

如果遇到问题：

1. 检查系统日志：`sudo journalctl -u cf-dns-manager -f`
2. 验证文件权限：`ls -la /opt/cf-dns-manager`
3. 测试端口连通性：`telnet localhost 3001`
4. 检查防火墙设置：`sudo ufw status`

更多信息请参考主 README.md 文档。
