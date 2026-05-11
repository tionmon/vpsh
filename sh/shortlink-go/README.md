# shortlink-go

极简短链系统（Go + SQLite），从 Python 版本重写，内存占用极低，运行稳定。

## 相比 Python 版本的优势

| 对比项 | Python 版 | Go 版 |
|--------|-----------|-------|
| 运行内存 | ~50-80MB | ~5-10MB |
| Docker镜像 | ~150MB | ~15MB |
| 启动时间 | 2-3秒 | <0.1秒 |
| 依赖 | Flask + Python运行时 | 单个静态二进制 |
| 并发能力 | GIL限制 | goroutine原生并发 |

## 新增功能

- **备注功能**：每条短链可添加备注，方便后续检查和识别用途
- **分组功能**（可选）：为短链分配分组（如"工作"、"个人"），支持下拉筛选和自动补全
- **标签功能**（可选）：为短链添加多个标签（逗号分隔），点击标签可快速筛选
- **多选删除**：支持勾选多条短链一键批量删除，便于维护
- **筛选过滤**：顶部筛选栏支持按分组和标签组合过滤
- **数据库兼容**：自动检测旧数据库并添加新列，平滑迁移

## 部署方式

### Docker Compose（推荐）

```yaml
services:
  shortlink:
    image: hunterluo/shortlink-go:latest
    container_name: shortlink-service
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
    environment:
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=admin123
    restart: unless-stopped
```

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `ADMIN_USERNAME` | admin | 管理员用户名 |
| `ADMIN_PASSWORD` | admin123 | 管理员密码 |
| `DATABASE_PATH` | /app/data/shortlinks.db | 数据库文件路径 |
| `SECRET_KEY` | change-this-secret-key | Cookie签名密钥 |
| `HOST` | 0.0.0.0 | 监听地址 |
| `PORT` | 5000 | 监听端口 |

## 内存优化措施

- SQLite WAL 模式 + 连接池限制（最多2连接）
- `embed.FS` 嵌入模板，零运行时文件读取
- HMAC 签名 Cookie 替代服务端 Session 存储
- `-ldflags="-s -w"` 编译减小二进制体积
- 异步更新访问计数，减少阻塞
