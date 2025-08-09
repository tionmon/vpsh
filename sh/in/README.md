## in.sh 使用说明

该脚本用于在 Debian 系统上快速配置 Docker 及 v2raya 服务，主要步骤如下：

### 1. 更换 apt 源
脚本会清空 `/etc/apt/sources.list` 并添加阿里云 Debian 源，加速软件包下载。

### 2. 安装常用工具
自动安装 curl、wget、sudo、unzip 等常用工具。

### 3. 配置 Docker 镜像加速
自动创建 `/etc/docker/daemon.json`，设置镜像加速地址。

### 4. 安装 Docker
调用同目录下的 `a.sh` 脚本进行 Docker 安装（需提前准备好 a.sh）。

### 5. 安装 Docker Compose
下载最新版 docker-compose 到 `/usr/local/bin/` 并赋予执行权限。

### 6. 部署 v2raya 服务
自动创建 `/home/docker/v2raya` 目录，下载 v2raya 的 docker-compose.yaml 文件，并启动服务。

### 7. 获取本机 IP 并输出访问地址
自动获取本机公网 IP，输出 v2raya 的访问地址。

---

#### 使用方法
1. 确保已上传并准备好 `in.sh` 和 `a.sh` 脚本。
2. 赋予执行权限：`chmod +x in.sh a.sh`
3. 以 root 用户运行：`sudo ./in.sh`

---

> 注意：本脚本仅适用于 Debian 系统，且需具备 root 权限。

---

## in.sh User Guide (English)

This script is designed to quickly set up Docker and v2raya services on Debian systems. Main steps:

### 1. Change apt Source
The script clears `/etc/apt/sources.list` and adds Aliyun's Debian mirror for faster package downloads.

### 2. Install Common Tools
Automatically installs curl, wget, sudo, and unzip.

### 3. Configure Docker Mirror
Creates `/etc/docker/daemon.json` and sets the registry mirror address.

### 4. Install Docker
Calls the `a.sh` script in the same directory to install Docker (make sure `a.sh` is prepared in advance).

### 5. Install Docker Compose
Downloads the latest docker-compose to `/usr/local/bin/` and grants execute permission.

### 6. Deploy v2raya Service
Creates `/home/docker/v2raya` directory, downloads v2raya's docker-compose.yaml, and starts the service.

### 7. Get Local IP and Output Access Address
Automatically retrieves the public IP and outputs the v2raya access address.

---

#### Usage
1. Make sure `in.sh` and `a.sh` scripts are uploaded and ready.
2. Grant execute permission: `chmod +x in.sh a.sh`
3. Run as root: `sudo ./in.sh`

---

> Note: This script is for Debian systems only and requires root privileges.
