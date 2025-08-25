---
title: agent
slug: agent
categories: []
tags: []
halo:
  site: https://17ya.de
  name: 526ade81-7720-4906-88fc-e47e13c1a3ec
  publish: false
---
# agent.sh - Nezha Agent 卸载脚本

## 功能描述
一键卸载 Nezha Agent 监控服务的脚本。

## 主要功能
- 停止 nezha-agent 服务
- 禁用开机自动启动
- 删除二进制文件和服务文件
- 重新加载 systemd 配置

## 使用方法
```bash
bash <(curl -Ls rnz.bbql.de)
```

## 适用系统
- Linux 系统（使用 systemd）
- 需要 root 权限
