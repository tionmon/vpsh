# Cloudflare DNS 记录管理脚本

这是一个功能强大的 Cloudflare DNS 记录管理脚本，支持批量添加、删除、查询 DNS 记录。

## 功能特性

- ✅ **批量操作**: 支持从 CSV 文件批量添加和删除 DNS 记录
- ✅ **交互式管理**: 提供友好的交互式界面
- ✅ **多种记录类型**: 支持 A、AAAA、CNAME、MX、TXT、SRV、NS、CAA 等记录类型
- ✅ **安全配置**: API 密钥安全存储
- ✅ **错误处理**: 完善的错误处理和提示
- ✅ **彩色输出**: 清晰的彩色终端输出

## 安装依赖

脚本需要以下依赖：

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq

# 或者使用 dnf
sudo dnf install curl jq

# macOS
brew install curl jq
```

## 快速开始

### 1. 配置 Cloudflare API

首先需要配置 Cloudflare API 信息：

```bash
./cfdns.sh -c
```

按提示输入：
- Cloudflare 邮箱
- Global API Key 或 API Token
- 默认域名（可选）

#### 获取 API 密钥

1. 登录 [Cloudflare 控制台](https://dash.cloudflare.com/)
2. 点击右上角头像 → "My Profile"
3. 选择 "API Tokens" 标签
4. 使用 "Global API Key" 或创建自定义 "API Token"

### 2. 基本使用

#### 查看帮助
```bash
./cfdns.sh -h
```

#### 列出所有 DNS 记录
```bash
./cfdns.sh -l -z example.com
```

#### 交互式添加记录
```bash
./cfdns.sh -a -z example.com
```

#### 交互式删除记录
```bash
./cfdns.sh -d -z example.com
```

### 3. 批量操作

#### 创建示例文件
```bash
./cfdns.sh -b example
```

这会创建 `dns_records_example.csv` 示例文件。

#### 创建删除示例文件
项目中包含 `delete_records_example.csv` 删除示例文件，展示了批量删除的用法。

#### 批量添加记录
```bash
./cfdns.sh -b add dns_records.csv -z example.com
```

#### 批量删除记录
```bash
./cfdns.sh -b delete delete_records.csv -z example.com
```

## 批量文件格式

### 批量添加格式

批量添加文件使用 CSV 格式，每行一条记录：

```csv
# 格式: 记录名称,记录类型,记录内容,TTL(可选)
# 注释行以 # 开头

# A 记录
www,A,192.168.1.100,3600
api,A,192.168.1.101,3600

# CNAME 记录
blog,CNAME,www.example.com,3600

# MX 记录
@,MX,10 mail.example.com,3600

# TXT 记录
@,TXT,"v=spf1 include:_spf.example.com ~all",3600
```

### 批量删除格式

批量删除文件支持两种格式：

```csv
# 方式1: 按记录 ID 删除
abcd1234
efgh5678

# 方式2: 按名称和类型删除
# 格式: 记录名称,记录类型
test,A
dev,CNAME

# 删除所有类型的同名记录（省略类型）
old-subdomain,
```

### 支持的记录类型

| 类型 | 说明 | 示例 |
|------|------|------|
| A | IPv4 地址 | `www,A,192.168.1.100,3600` |
| AAAA | IPv6 地址 | `www,AAAA,2001:db8::1,3600` |
| CNAME | 别名记录 | `blog,CNAME,www.example.com,3600` |
| MX | 邮件交换 | `@,MX,10 mail.example.com,3600` |
| TXT | 文本记录 | `@,TXT,"v=spf1 include:_spf.example.com ~all",3600` |
| SRV | 服务记录 | `_sip._tcp,SRV,10 5 5060 sip.example.com,3600` |
| NS | 名称服务器 | `subdomain,NS,ns1.example.com,3600` |
| CAA | 证书颁发机构授权 | `@,CAA,"0 issue \"letsencrypt.org\"",3600` |

## 命令行选项

```
选项:
  -h, --help          显示帮助信息
  -c, --config        配置 Cloudflare API 信息
  -l, --list          列出所有 DNS 记录
  -a, --add           添加 DNS 记录
  -d, --delete        删除 DNS 记录
  -b, --batch         批量操作模式
  -z, --zone          指定域名区域

示例:
  ./cfdns.sh -c                           # 配置 API 信息
  ./cfdns.sh -l -z example.com            # 列出 example.com 的所有记录
  ./cfdns.sh -a -z example.com            # 交互式添加记录
  ./cfdns.sh -b add records.csv           # 批量添加记录
  ./cfdns.sh -b delete delete.csv         # 批量删除记录
  ./cfdns.sh -d -z example.com            # 交互式删除记录
```

## 使用场景

### 1. 网站迁移
当需要迁移网站到新服务器时，可以批量更新 DNS 记录：

```csv
www,A,新服务器IP,300
api,A,新服务器IP,300
ftp,A,新服务器IP,300
```

### 2. 子域名批量创建
为不同环境创建子域名：

```csv
dev,A,192.168.1.10,300
test,A,192.168.1.11,300
staging,A,192.168.1.12,300
prod,A,192.168.1.13,3600
```

### 3. 邮件服务配置
配置邮件相关的 DNS 记录：

```csv
@,MX,10 mail.example.com,3600
@,TXT,"v=spf1 include:_spf.example.com ~all",3600
_dmarc,TXT,"v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com",3600
```

### 4. CDN 配置
配置 CDN 相关记录：

```csv
cdn,CNAME,cdn.cloudflare.com,3600
static,CNAME,cdn.cloudflare.com,3600
images,CNAME,cdn.cloudflare.com,3600
```

### 5. 批量删除场景

#### 清理测试环境
删除开发和测试相关的记录：

```csv
dev,A
test,A
staging,A
dev-api,A
```

#### 清理过期验证记录
删除域名验证相关的记录：

```csv
_acme-challenge,TXT
google-site-verification,TXT
_verification,TXT
```

#### 按记录 ID 精确删除
当需要精确删除特定记录时：

```csv
abcd1234
efgh5678
ijkl9012
```

## 安全注意事项

1. **API 密钥保护**: 配置文件 `~/.cfdns_config` 权限设置为 600，仅当前用户可读
2. **备份重要记录**: 在批量操作前，建议先导出现有记录
3. **测试环境**: 建议先在测试域名上验证脚本功能
4. **API 限制**: 脚本包含延迟机制，避免触发 Cloudflare API 限制

## 故障排除

### 常见错误

1. **"缺少依赖"错误**
   ```bash
   sudo apt-get install curl jq
   ```

2. **"配置文件不存在"错误**
   ```bash
   ./cfdns.sh -c
   ```

3. **"无法获取区域信息"错误**
   - 检查域名是否正确
   - 确认域名已添加到 Cloudflare
   - 验证 API 密钥是否有效

4. **"API 认证失败"错误**
   - 重新配置 API 信息
   - 确认邮箱和 API 密钥正确

### 调试模式

如需调试，可以在脚本开头添加：
```bash
set -x  # 启用调试模式
```

## 许可证

本脚本基于 MIT 许可证发布，可自由使用和修改。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 更新日志

### v1.0
- 初始版本
- 支持基本的 DNS 记录管理
- 支持批量操作
- 交互式界面
- 完善的错误处理