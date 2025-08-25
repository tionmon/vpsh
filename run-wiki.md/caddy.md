---
title: caddy
slug: caddy
categories: []
tags: []
halo:
  site: https://17ya.de
  name: f10104ed-05f6-4c48-b65a-664af0cca905
  publish: false
---
# caddy.sh - Caddy Web 服务器安装脚本

## 功能描述
自动检测并安装 Caddy Web 服务器的脚本。

## 主要功能
- 检查 Caddy 是否已安装
- 安装必要的依赖包
- 导入 Caddy 官方 GPG 密钥
- 添加 Caddy 官方软件源
- 安装并启用 Caddy 服务

## 使用方法
```bash
bash <(curl -Ls icaddy.bbql.de)
```

## 适用系统
- Debian/Ubuntu 系统
- 需要 sudo 权限

## 特点
- 智能检测，避免重复安装
- 使用官方软件源，确保版本稳定
- 自动启用开机自启动
