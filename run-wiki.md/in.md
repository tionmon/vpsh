---
halo:
  site: https://17ya.de
  name: 7a4018ed-066a-4cff-8bbe-edfdad00edd7
  publish: false
---
# in.sh - Docker 和 V2rayA 一键安装脚本

## 功能描述
一键安装 Docker 环境和 V2rayA 代理服务的脚本。

## 主要功能
- 配置阿里云 Debian 软件源
- 安装基础工具（curl, wget, sudo, unzip）
- 配置 Docker 镜像加速器
- 自动安装 Docker
- 部署 V2rayA 代理服务
- 自动获取并显示访问地址

## 使用方法
```bash
bash <(curl -Ls in.bbql.de)
```

## 安装内容
- Docker 容器引擎
- V2rayA Web 管理界面
- 多个 Docker 镜像加速源

## 访问方式
安装完成后，通过 `http://服务器IP:2017` 访问 V2rayA 管理界面

## 适用系统
- Debian 系统
- 需要 root 权限

## 特点
- 一键部署，无需手动配置
- 自动配置镜像加速
- 提供多个备用镜像源
