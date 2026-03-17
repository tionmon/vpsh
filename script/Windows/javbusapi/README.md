# JavBus API Telegram Bot

基于 JavBus API 的 Telegram 机器人，支持浏览、搜索、批量获取磁力链接，并可推送到 Symedia 115 离线下载。

---

## 在全新 Debian 12 服务器上部署

### 1. 安装 Docker 和 Docker Compose

```bash
# 更新系统
apt update && apt upgrade -y

# 安装必要依赖
apt install -y ca-certificates curl gnupg

# 添加 Docker 官方 GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 添加 Docker apt 源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 验证安装
docker --version
docker compose version
```

### 2. 上传项目文件

将项目文件上传到服务器（以 `/opt/javbusbot` 为例）：

```bash
mkdir -p /opt/javbusbot
# 方式一：通过 scp 从本地上传
# scp -r ./* root@your-server:/opt/javbusbot/

# 方式二：直接在服务器上创建文件（略）
```

确保目录结构如下：

```
/opt/javbusbot/
├── bot.py
├── config.py
├── api_client.py
├── handlers/
│   ├── __init__.py
│   ├── start.py
│   ├── movies.py
│   ├── movie_detail.py
│   ├── star.py
│   └── symedia.py
├── utils/
│   ├── __init__.py
│   ├── common.py
│   ├── formatters.py
│   └── keyboards.py
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
└── .env
```

### 3. 配置环境变量

```bash
cd /opt/javbusbot

# 从示例创建 .env
cp .env.example .env

# 编辑 .env 填入你的配置
nano .env
```

`.env` 文件内容：

```ini
# ═══ 必填 ═══
# 从 @BotFather 获取
BOT_TOKEN=your_telegram_bot_token_here

# ═══ 可选 ═══
# API 认证 Token（如果你的 JavBus API 设置了认证）
API_AUTH_TOKEN=

# ═══ Symedia 推送（可选）═══
# Symedia 服务地址，例: http://192.168.1.100:8095
SYMEDIA_URL=
# Symedia API token，默认 symedia
SYMEDIA_TOKEN=symedia
# API 路径，通常不需要修改
SYMEDIA_API_PATH=/api/v1/plugin/cloud_helper/add_offline_urls_115
# 115 网盘目标文件夹 ID，0 = 根目录
SYMEDIA_CID=0
```

> **注意**: `DEFAULT_API_URL` 不需要在 `.env` 中设置，`docker-compose.yaml` 已自动配置为内部地址 `http://javbusapi:3000`。

### 4. 构建并启动服务

```bash
cd /opt/javbusbot

# 构建并启动（后台运行）
docker compose up -d --build

# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f javbusbot
```

启动后会运行两个容器：

| 容器 | 说明 | 端口 |
|------|------|------|
| `javbusapi` | JavBus API 服务 | 3030 → 3000 |
| `javbusbot` | Telegram Bot | 无（仅 polling） |

### 5. 验证

在 Telegram 中向你的 Bot 发送：

```
/start
```

应该看到欢迎消息和命令列表。

---

## 常用运维命令

```bash
# 查看日志
docker compose logs -f javbusbot

# 重启 Bot
docker compose restart javbusbot

# 停止所有服务
docker compose down

# 更新代码后重新构建
docker compose up -d --build

# 查看资源占用
docker stats
```

---

## Bot 命令参考

### 配置

| 命令 | 说明 |
|------|------|
| `/setapi <url>` | 设置 API 地址（Docker 部署通常不需要） |
| `/sleep <秒>` | 设置批量请求延迟，范围 0-5 秒，默认 1 秒 |
| `/symedia` | 查看 Symedia 推送配置 |
| `/symedia set <url>` | 设置 Symedia 地址 |
| `/symedia token <t>` | 设置 Symedia Token |
| `/symedia cid <id>` | 设置 115 目标文件夹 ID |
| `/symedia test` | 测试 Symedia 连接 |

### 浏览与搜索

| 命令 | 说明 |
|------|------|
| `/movies` | 浏览影片列表（第1页） |
| `/movies 2` | 浏览第2页 |
| `/movies uncensored` | 无码影片 |
| `/movies star <id>` | 演员作品 |
| `/search <关键词>` | 搜索影片 |

### 详情与磁力

| 命令 | 说明 |
|------|------|
| `SSIS-406` | 直接发送番号 → 详情 + 最佳磁力 |
| `/movie SSIS-406` | 仅查看详情 |
| `/magnets SSIS-406` | 获取所有磁力链接 |
| `/star <id>` | 演员信息 |

### 批量磁力

| 命令 | 说明 |
|------|------|
| `/movies_magnets all 1` | 获取第1页所有磁力 |
| `/movies_magnets all 1-3` | 获取1-3页磁力（最多5页） |
| `/search_magnets 三上 all 1` | 搜索并批量获取 |
| `/search_magnets 三上 all 1-2` | 搜索批量获取多页 |

### Symedia 自动推送 (sa)

在任何获取磁力的命令末尾加 `sa`，获取后会自动推送到 Symedia：

| 命令 | 说明 |
|------|------|
| `SSIS-406 sa` | 获取最佳磁力 → 推送到 Symedia |
| `/movies_magnets all 1 sa` | 批量获取 → 推送 |
| `/search_magnets 三上 all 1 sa` | 搜索批量 → 推送 |

---

## 项目结构

```
├── bot.py                  # 主入口，命令注册，回调处理
├── config.py               # 配置管理（API / Sleep / Symedia）
├── api_client.py            # JavBus API 异步客户端（带超时重试）
├── handlers/
│   ├── start.py            # /start, /help, /setapi, /sleep
│   ├── movies.py           # /movies, /search
│   ├── movie_detail.py     # /movie, /magnets（含 LRU 缓存）
│   ├── star.py             # /star
│   └── symedia.py          # /symedia, 推送逻辑
├── utils/
│   ├── common.py           # 公共装饰器
│   ├── formatters.py       # 消息格式化
│   └── keyboards.py        # Inline 键盘构建
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
└── .env.example
```

---

## 不使用 Docker 直接运行（可选）

```bash
# 安装 Python 3.11+
apt install -y python3 python3-pip python3-venv

# 创建虚拟环境
cd /opt/javbusbot
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
nano .env
# 必须手动设置 DEFAULT_API_URL 指向你的 JavBus API 服务

# 运行
python bot.py
```

> 注意：直接运行需要你自行部署 JavBus API 服务（`ovnrain/javbus-api`），并在 `.env` 中设置 `DEFAULT_API_URL`。
