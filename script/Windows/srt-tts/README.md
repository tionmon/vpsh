# SRT 字幕转语音

上传 SRT 字幕文件，自动生成与字幕时间表对齐的语音 MP3。

## 功能

- Web UI 拖拽上传 SRT 文件
- 自动调整语速匹配每条字幕的时间窗口
- 多种声音可选（中/英/日/韩等）
- 并发生成 + 两轮重试机制
- 分块拼装，支持超长文件
- 实时进度显示
- 生成的 MP3 文件名基于上传文件名

## 文件结构

```
srt-tts/
├── web_srt_tts.py          # Web 服务器（主程序）
├── srt_to_speech.py        # CLI 命令行工具（可选）
├── setup.sh                # 一键安装脚本
├── README.md
└── templates/
    └── index.html          # Web 前端页面
```

## 在全新 Debian 12 服务器上部署

### 1. 上传文件

将整个 `srt-tts/` 文件夹上传到服务器，例如放在 `/home/srt-tts/`：

```bash
# 在本地执行（替换 YOUR_SERVER_IP）
scp -r srt-tts/ root@YOUR_SERVER_IP:/home/srt-tts/
```

### 2. 运行安装脚本

```bash
ssh root@YOUR_SERVER_IP
cd /home/srt-tts
bash setup.sh
```

安装脚本会自动完成：
- 安装 `python3`、`pip`、`ffmpeg` 系统依赖
- 创建 Python 虚拟环境 `~/srt_tts_venv`
- 安装 `edge-tts`、`pysrt`、`pydub`、`flask`

### 3. 启动服务

```bash
source ~/srt_tts_venv/bin/activate
cd /home/srt-tts
python3 web_srt_tts.py --port 5000
```

浏览器打开 `http://YOUR_SERVER_IP:5000` 即可使用。

### 4. 后台运行（可选）

使用 `nohup` 让服务在后台持续运行：

```bash
source ~/srt_tts_venv/bin/activate
cd /home/srt-tts
nohup python3 web_srt_tts.py --port 5000 > srt_tts.log 2>&1 &
```

查看日志：

```bash
tail -f /home/srt-tts/srt_tts.log
```

停止服务：

```bash
pkill -f web_srt_tts.py
```

### 5. 开放防火墙端口（如需要）

```bash
# iptables
sudo iptables -A INPUT -p tcp --dport 5000 -j ACCEPT

# 或 ufw
sudo ufw allow 5000/tcp
```

## Web UI 使用

1. 打开浏览器访问 `http://服务器IP:5000`
2. 拖拽或点击上传 `.srt` 字幕文件
3. 在右侧面板选择声音、调整参数
4. 点击 **开始生成**
5. 等待进度条完成
6. 点击 **下载 MP3**

## CLI 使用（可选）

```bash
source ~/srt_tts_venv/bin/activate
cd /home/srt-tts

# 基本用法
python3 srt_to_speech.py input.srt -o output.mp3

# 指定声音和并发
python3 srt_to_speech.py input.srt -o output.mp3 -v zh-CN-XiaoxiaoNeural -c 8

# 列出中文声音
python3 srt_to_speech.py --list-voices zh-CN
```

## 常用声音

| 名称 | 性别 | 风格 |
|------|------|------|
| `zh-CN-YunxiNeural` | 男 | 年轻（默认） |
| `zh-CN-YunjianNeural` | 男 | 成熟 |
| `zh-CN-YunyangNeural` | 男 | 新闻播报 |
| `zh-CN-XiaoxiaoNeural` | 女 | 甜美 |
| `zh-CN-XiaoyiNeural` | 女 | 活泼 |
| `en-US-AriaNeural` | 女 | 英语 |
| `ja-JP-NanamiNeural` | 女 | 日语 |

## 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 声音 | `zh-CN-YunxiNeural` | TTS 声音 |
| 并发数 | 5 | 同时生成的请求数（1-64） |
| 音量 | 0% | -50% ~ +50% |
| 音调 | 0Hz | -30Hz ~ +30Hz |
| 时长容差 | 15% | 允许的时长偏差 |
| 语速调整次数 | 2 | 每条字幕的语速适配重试次数 |
| 网络重试次数 | 3 | TTS 请求失败的重试次数 |
