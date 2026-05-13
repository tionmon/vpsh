# proxy.sh

一个用于 Linux 服务器和开发环境的代理管理脚本，专门解决“临时开代理容易，统一清理很麻烦”的问题。

它可以一键设置、清除和检查多种常见工具的代理配置，包括：

- Shell 环境变量
- Docker
- Git
- APT
- NPM
- PIP
- Wget

这个项目的目标很直接：用一份脚本，把代理的开启、关闭、排查和复用都收拢到一个地方。

## 特性

- 支持 `set` / `unset` / `status`
- 支持只输入端口号，自动补全为 `http://127.0.0.1:<port>`
- 支持分别配置 Docker、Git、APT、NPM、PIP、Wget
- 支持 `--all` 批量处理
- Docker 和 APT 通过真实配置文件生效
- Wget 配置会先备份原始文件，再由脚本接管

## 适用场景

- 本地有 Clash、v2ray、sing-box、socks/http 代理，需要快速给命令行工具接入代理
- 服务器临时需要走代理拉镜像、拉包、下载依赖
- Docker、Git、APT、NPM、PIP 代理配置经常切换，想要统一管理
- 想快速查看“当前到底哪些地方还挂着代理”

## 安装

### 方式一：下载到当前目录

如果你只是想把脚本保存到当前目录并直接使用：

```bash
curl -fsSL 'https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/run/sysproxy.sh' -o proxy.sh
chmod +x proxy.sh
```

之后即可直接执行：

```bash
bash proxy.sh docker-set 8888
bash proxy.sh status
source proxy.sh set 8888
```

### 方式二：安装到系统路径

如果你希望在任意目录都能直接调用：

```bash
sudo curl -fsSL 'https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/run/sysproxy.sh' -o /usr/local/bin/proxy.sh
sudo chmod +x /usr/local/bin/proxy.sh
```

然后就可以这样使用：

```bash
proxy.sh docker-set 8888
proxy.sh status
```

## 一个常见误区

很多人会直接用“在线执行”的方式运行脚本，例如：

```bash
bash <(curl -fsSL 'https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/run/sysproxy.sh')
```

这种方式只是“执行了远程脚本”，并不会把脚本保存到本地。

所以命令执行完之后，当前目录里并不会出现 `proxy.sh`，后续自然也就无法继续使用：

```bash
bash proxy.sh docker-set 8888
```

如果你希望后续反复调用，请务必使用 `-o proxy.sh` 显式下载到本地。

## 用法

### 1. 设置当前 Shell 代理

```bash
source proxy.sh set 8888
```

等价于：

```bash
source proxy.sh set http://127.0.0.1:8888
```

这会设置：

- `http_proxy`
- `https_proxy`
- `ftp_proxy`
- `all_proxy`
- `no_proxy`

注意：这里必须使用 `source`，否则环境变量只会在子进程里生效。

### 2. 清除当前 Shell 代理

```bash
source proxy.sh unset
```

### 3. 只设置 Docker 代理

```bash
bash proxy.sh docker-set 8888
```

### 4. 只清除 Docker 代理

```bash
bash proxy.sh docker-unset
```

### 5. Shell + 指定工具一起设置

```bash
source proxy.sh set 8888 --docker --git --npm
```

### 6. 一次性设置全部代理

```bash
source proxy.sh set 8888 --all
```

### 7. 一次性清除全部代理

```bash
source proxy.sh unset --all
```

### 8. 查看当前代理状态

```bash
bash proxy.sh status
```

## 支持的代理地址格式

脚本会自动解析以下写法：

```bash
source proxy.sh set 8888
source proxy.sh set 127.0.0.1:8888
source proxy.sh set http://127.0.0.1:8888
source proxy.sh set socks5://127.0.0.1:1080
```

默认值为：

```bash
http://127.0.0.1:8888
```

## 实际会修改哪些配置

### Shell

修改当前会话环境变量，不写入系统文件。

### Docker

写入：

```text
/etc/systemd/system/docker.service.d/http-proxy.conf
```

并执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### Git

写入 Git 全局配置：

```bash
git config --global http.proxy
git config --global https.proxy
```

### APT

写入：

```text
/etc/apt/apt.conf.d/95proxy
```

### NPM

写入：

```bash
npm config set proxy
npm config set https-proxy
```

### PIP

写入：

```text
~/.config/pip/pip.conf
```

### Wget

写入：

```text
~/.wgetrc
```

如果原本已经存在 `.wgetrc`，脚本会先备份为：

```text
~/.wgetrc.bak.proxy
```

## 注意事项

- `source proxy.sh set ...` 和 `source proxy.sh unset ...` 用于修改当前 shell 环境变量
- `bash proxy.sh ...` 适合执行 Docker、Git、APT、NPM、PIP、Wget 相关操作
- Docker 和 APT 需要 `sudo`
- Docker 配置依赖 `systemd`
- 如果你的系统不是 Debian/Ubuntu 系，APT 相关功能并不适用
- 清除 Wget 代理时，只会删除脚本自己接管的 `.wgetrc`

## 常用示例

```bash
# 只给当前终端设置代理
source proxy.sh set 7890

# 当前终端 + Docker
source proxy.sh set 7890 --docker

# 当前终端 + Git + NPM + PIP
source proxy.sh set 7890 --git --npm --pip

# 所有支持的代理项全部设置
source proxy.sh set 7890 --all

# 查看当前状态
bash proxy.sh status

# 清理所有代理
source proxy.sh unset --all
```

## 项目结构

```text
.
├── proxy.sh
└── README.md
```

## 适合发布到博客的说明角度

如果你准备同步写一篇博客，这个项目很适合从下面几个角度展开：

- 为什么“在线执行脚本”不等于“安装脚本”
- 为什么 `source` 和 `bash` 的行为不同
- 为什么 Docker、APT、Git、NPM、PIP 的代理总是分散且难以统一
- 如何把临时代理、持久代理和排查命令做成一个可复用的小工具

## License

如果你准备公开发布，建议补一个许可证文件，例如 `MIT`。
