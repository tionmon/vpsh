# MetaTube VPS One-Click Installer

一个面向 VPS / 云服务器的 MetaTube 一键部署脚本，支持：

- 直接部署：`systemd + 原生二进制`
- Docker 部署：`docker compose + PostgreSQL`
- 自动检测并安装 Docker
- 自定义实例名、安装目录、端口、TOKEN
- 自动设置开机自启

这个脚本适合希望快速把 MetaTube 部署到 Linux VPS 上的用户，尽量减少手动安装、配环境、写服务文件的步骤。

项目脚本文件：

- [metatube-vps-install.sh](/C:/Users/T/Desktop/metatube/metatube-vps-install.sh)

官方部署文档参考：

- [MetaTube Server Deployment](https://metatube-community.github.io/wiki/server-deployment/)

## 特性

- 支持两种部署方式，兼顾轻量和性能
- 直接部署默认目录为 `/home/systemd/<name>`
- Docker 部署默认目录为 `/home/docker/<name>`
- 两种模式都支持自定义安装目录
- Docker 模式下会自动检查 `docker`
- 如果服务器未安装 Docker，会自动安装并设置开机启动
- 支持输入自定义 `TOKEN`
- `TOKEN` 可留空，留空即不设置访问密码
- 自动拉取最新版本，不需要手动修改脚本中的版本号
- `x86_64` 机器优先尝试更高性能的 `x86_64-v3` 发行包

## 部署模式说明

### 1. 直接部署

适合：

- 追求简单、轻量
- 不想额外安装 Docker
- 单实例、小中型使用场景

特点：

- 使用 `systemd` 管理服务
- 使用 SQLite 作为数据存储
- 开机自启
- 日志可直接通过 `journalctl` 查看

默认目录：

```bash
/home/systemd/<name>
```

### 2. Docker 部署

适合：

- 更偏向官方推荐的服务化部署方式
- 希望容器化管理
- 对稳定性、迁移性和数据库能力要求更高

特点：

- 使用 `docker compose` 编排
- 自动部署 PostgreSQL
- 自动检测并安装 Docker
- 自动设置 Docker 开机启动

默认目录：

```bash
/home/docker/<name>
```

## 环境要求

- Linux VPS
- 使用 `root` 运行脚本，或通过 `sudo` 执行
- 系统具备 `systemd`
- 服务器可以访问 GitHub 和 Docker 镜像源

已考虑的系统家族：

- Debian / Ubuntu
- CentOS / Rocky / AlmaLinux / Fedora
- openSUSE
- Arch Linux

## 快速开始

先给脚本添加执行权限：

```bash
chmod +x metatube-vps-install.sh
```

然后运行：

```bash
sudo bash metatube-vps-install.sh
```

脚本会依次提示你输入：

1. 实例名称
2. 服务端口
3. TOKEN
4. 部署方式
5. 安装目录

如果某项直接回车，则使用默认值。

## 交互示例

### 直接部署示例

```text
Input instance name [metatube]: demo
Input service port [8080]: 8081
Input TOKEN (press Enter to leave empty):
Choose deployment mode:
1. Direct deploy (systemd + SQLite, lighter setup)
2. Docker deploy (docker compose + PostgreSQL, closer to the high-performance official setup)
Input option [1/2]: 1
Input install directory [/home/systemd/demo]:
```

### Docker 部署示例

```text
Input instance name [metatube]: mt
Input service port [8080]: 8080
Input TOKEN (press Enter to leave empty): my-secret-token
Choose deployment mode:
1. Direct deploy (systemd + SQLite, lighter setup)
2. Docker deploy (docker compose + PostgreSQL, closer to the high-performance official setup)
Input option [1/2]: 2
Input install directory [/home/docker/mt]:
```

## 部署完成后

### 如果是直接部署

查看服务状态：

```bash
systemctl status <name>
```

查看日志：

```bash
journalctl -u <name> -f
```

重启服务：

```bash
systemctl restart <name>
```

### 如果是 Docker 部署

查看容器状态：

```bash
docker compose -f /home/docker/<name>/compose.yaml ps
```

查看日志：

```bash
docker compose -f /home/docker/<name>/compose.yaml logs -f
```

重启服务：

```bash
docker compose -f /home/docker/<name>/compose.yaml restart
```

## TOKEN 说明

脚本支持设置一个自定义 `TOKEN`。

- 输入内容：启用密码保护
- 直接回车：不设置密码

如果你准备将服务暴露在公网，建议设置 `TOKEN`。

## 默认行为说明

### 直接部署模式

- 自动下载 MetaTube 最新 release
- 自动选择适合当前 CPU 架构的二进制
- `x86_64` 且 CPU 支持时，优先使用 `amd64-v3`
- 自动创建 systemd 服务
- 自动设置开机自启

### Docker 模式

- 自动检查 Docker 是否已安装
- 未安装时自动安装 Docker
- 自动启用 Docker 开机启动
- 自动生成 `compose.yaml`
- 自动启动 PostgreSQL 和 MetaTube 服务

## 目录结构示例

### 直接部署

```text
/home/systemd/demo/
├── metatube-server
└── data/
    └── metatube.db
```

### Docker 部署

```text
/home/docker/demo/
├── compose.yaml
└── postgres/
```

## 适合发布到博客的摘要

如果你准备把这份内容同步发到博客，可以直接使用下面这段简介：

> 这是一个为 MetaTube 编写的 VPS 一键部署脚本，支持原生 systemd 部署和 Docker Compose 部署两种模式。脚本可以自动检测并安装 Docker，支持自定义安装目录、端口和 TOKEN，并自动完成服务注册与开机自启，适合在 Linux 云服务器上快速落地 MetaTube。

## 常见问题

### 1. 这个脚本适合什么系统？

适合使用 `systemd` 的 Linux 发行版，不适用于 Windows Server。

### 2. 为什么 Docker 模式默认带 PostgreSQL？

因为这更接近文档中的高性能、可维护部署思路，也更适合长期运行。

### 3. 可以不开密码吗？

可以。输入 `TOKEN` 时直接回车即可。

### 4. 可以部署多个实例吗？

可以。给不同实例填写不同的名称、目录和端口即可。

## 注意事项

- 请确保服务器防火墙已放行对应端口
- 如果使用云服务器，请同时检查安全组规则
- Docker 模式首次拉取镜像可能会稍慢
- 如果 GitHub 或镜像源访问较慢，安装过程会受网络影响

## License

此仓库仅提供一键部署脚本与说明文档。MetaTube 本体的许可协议请以其官方仓库为准。
