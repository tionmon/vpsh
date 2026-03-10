# 🧲 Sehuatang 磁力爬虫服务

基于 Flask + DrissionPage 的 Sehuatang 论坛磁力/ED2K 链接爬虫，提供 Web 操作界面。

## 功能

- 🕷️ **Web 爬取** — 输入论坛 URL + 页码范围，自动爬取 magnet/ed2k 链接
- 🔐 **访问鉴权** — 密码保护，默认密码 `admin`
- 📁 **结果下载** — 爬取结果可在线查看、下载（txt/json 格式）
- ⏰ **定时任务** — 支持多个预设定时爬取（cron 表达式）
- 🤖 **TG 通知** — 可选对接 Telegram Bot，任务完成自动发送结果文件
- 🛡️ **风控规避** — 自动处理 Cloudflare 验证 + 年龄验证 + 指数退避重试

---

## 🚀 从零部署（Debian / Ubuntu）

### 1. 获取代码

```bash
# 上传项目文件夹到服务器，或用 scp/rsync：
scp -r sehuatang-server/ user@your-server:/opt/sehuatang-server/

# 登录服务器
ssh user@your-server
cd /opt/sehuatang-server
```

### 2. 一键安装

```bash
chmod +x setup.sh start.sh stop.sh
bash setup.sh
```

> 脚本会自动安装：Python3、venv、Chromium 浏览器、中文字体、所有 Python 依赖

### 3. 启动服务

```bash
bash start.sh
```

### 4. 访问

浏览器打开 `http://<服务器IP>:9898`

- **默认密码**: `admin`
- 建议登录后立即在「设置」页修改密码

### 5. 停止服务

```bash
bash stop.sh
```

---

## 📖 使用说明

### 手动爬取

1. 在「爬取任务」tab 输入论坛 URL（如 `https://sehuatang.net/forum-160-1.html`）
2. 设置起始页和结束页
3. 点击「开始爬取」，实时查看日志和统计
4. 完成后在「结果文件」tab 下载结果

### 定时任务

1. 在「定时任务」tab 添加任务
2. 填写 cron 表达式：`分 时 日 月 星期`
   - 例: `0 8 * * *` = 每天 08:00
   - 例: `0 */6 * * *` = 每 6 小时
   - 例: `30 22 * * 1-5` = 工作日 22:30
3. 可为每个任务指定不同的 TG 频道

### Telegram 通知

1. 在「设置」→「Telegram 设置」中，开启并填写 Bot Token 和默认 Chat ID
2. 每个定时任务可指定独立的 TG 频道（留空则用默认）
3. 任务完成后会自动发送结果文件到对应频道

---

## 📁 项目结构

```
sehuatang-server/
├── app.py              # Flask 主应用 (端口 9898)
├── scraper.py          # DrissionPage 爬虫引擎
├── scheduler.py        # APScheduler 定时任务
├── tg_notify.py        # Telegram 通知
├── config.json         # 运行时配置
├── requirements.txt    # Python 依赖
├── setup.sh            # 一键安装
├── start.sh            # 后台启动
├── stop.sh             # 停止服务
├── results/            # 爬取结果输出目录
├── app.log             # 运行日志
└── templates/
    ├── login.html      # 登录页
    └── index.html      # 主控制台
```

## 常用板块 ID

| 板块 | URL 示例 |
|------|----------|
| 亚洲有码原创 | `forum-37-1.html` |
| 亚洲无码原创 | `forum-39-1.html` |
| 高清中文字幕 | `forum-103-1.html` |
| 国产自拍 | `forum-160-1.html` |

---

## ⚠️ 注意事项

- 首次运行如遇 Chromium 路径问题，可手动检查: `which chromium` 或 `which chromium-browser`
- 若需反代或 HTTPS，建议用 Nginx + Let's Encrypt
- 日志文件: `tail -f app.log`
- 防火墙需放行 9898 端口: `sudo ufw allow 9898`
