#!/bin/bash

# Debian 12 系统安全重置脚本
# 这是一个更安全的版本，会在每个步骤前询问确认
# 建议先使用此版本测试

set -e

echo "======================================"
echo "Debian 12 系统安全重置脚本"
echo "此版本会在每个步骤前询问确认"
echo "======================================"

# 全局确认
read -p "确定要开始系统重置吗？输入 'YES' 确认: " confirm
if [ "$confirm" != "YES" ]; then
    echo "操作已取消"
    exit 1
fi

# 函数：询问确认
ask_confirmation() {
    local message="$1"
    read -p "$message (Y/n): " choice
    case "$choice" in 
        n|N ) return 1;;
        * ) return 0;;
    esac
}

echo "开始系统重置..."

# 1. Docker清理
if ask_confirmation "是否清理Docker服务和数据？"; then
    echo "[1] 清理Docker..."
    if command -v docker &> /dev/null; then
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker rmi $(docker images -q) 2>/dev/null || true
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        systemctl stop docker 2>/dev/null || true
        systemctl disable docker 2>/dev/null || true
        
        if ask_confirmation "是否完全卸载Docker？"; then
            apt-get remove --purge -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
            rm -rf /var/lib/docker
            rm -rf /etc/docker
            rm -rf ~/.docker
        fi
    fi
fi

# 2. Snap包清理
if ask_confirmation "是否清理所有Snap包？"; then
    echo "[2] 清理Snap包..."
    if command -v snap &> /dev/null; then
        snap list | awk 'NR>1 {print $1}' | xargs -I {} snap remove {} 2>/dev/null || true
        if ask_confirmation "是否完全卸载Snap？"; then
            systemctl stop snapd 2>/dev/null || true
            systemctl disable snapd 2>/dev/null || true
            apt-get remove --purge -y snapd 2>/dev/null || true
            rm -rf /snap /var/snap /var/lib/snapd
        fi
    fi
fi

# 3. Web服务器清理
if ask_confirmation "是否清理Web服务器(Apache/Nginx)？"; then
    echo "[3] 清理Web服务器..."
    for service in apache2 nginx lighttpd; do
        systemctl stop $service 2>/dev/null || true
        systemctl disable $service 2>/dev/null || true
        if ask_confirmation "是否卸载 $service？"; then
            apt-get remove --purge -y $service 2>/dev/null || true
        fi
    done
    if ask_confirmation "是否删除Web目录(/var/www)？"; then
        rm -rf /var/www
    fi
fi

# 4. 数据库服务清理
if ask_confirmation "是否清理数据库服务？"; then
    echo "[4] 清理数据库服务..."
    for service in mysql mariadb-server postgresql redis-server mongodb; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            if ask_confirmation "是否停止并卸载 $service？"; then
                systemctl stop $service 2>/dev/null || true
                systemctl disable $service 2>/dev/null || true
                apt-get remove --purge -y $service 2>/dev/null || true
            fi
        fi
    done
    if ask_confirmation "是否删除数据库数据目录？"; then
        rm -rf /var/lib/mysql /var/lib/postgresql /var/lib/redis /var/lib/mongodb
    fi
fi

# 5. 开发工具清理
if ask_confirmation "是否清理开发工具(Node.js, Python pip, Go, Java)？"; then
    echo "[5] 清理开发工具..."
    if ask_confirmation "是否卸载Node.js和npm？"; then
        apt-get remove --purge -y nodejs npm 2>/dev/null || true
        rm -rf ~/.npm
    fi
    if ask_confirmation "是否清理Python pip缓存？"; then
        apt-get remove --purge -y python3-pip 2>/dev/null || true
        rm -rf ~/.pip
    fi
    if ask_confirmation "是否卸载Go？"; then
        apt-get remove --purge -y golang-go 2>/dev/null || true
        rm -rf ~/.go /usr/local/go
    fi
    if ask_confirmation "是否卸载Java？"; then
        apt-get remove --purge -y openjdk-* 2>/dev/null || true
        rm -rf ~/.java
    fi
fi

# 6. 日志清理
if ask_confirmation "是否清理系统日志？"; then
    echo "[6] 清理日志文件..."
    journalctl --vacuum-time=7d 2>/dev/null || true
    if ask_confirmation "是否删除旧的日志文件？"; then
        find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
        find /var/log -type f -name "*.old" -delete 2>/dev/null || true
    fi
fi

# 7. 缓存清理
if ask_confirmation "是否清理系统缓存？"; then
    echo "[7] 清理缓存文件..."
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y
    rm -rf /tmp/* /var/tmp/*
fi

# 8. 用户目录清理
if ask_confirmation "是否清理用户目录缓存？"; then
    echo "[8] 清理用户目录..."
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            if ask_confirmation "是否清理用户 $username 的缓存？"; then
                rm -rf "$user_home"/.cache
                rm -rf "$user_home"/.local/share/Trash
                rm -rf "$user_home"/.mozilla
                rm -rf "$user_home"/.chrome
            fi
        fi
    done
fi

# 9. 服务清理
if ask_confirmation "是否清理非必要的启动服务？"; then
    echo "[9] 清理启动项..."
    echo "正在扫描服务..."
    systemctl list-unit-files --type=service --state=enabled | grep -v "@" | awk '{print $1}' | while read service; do
        case $service in
            ssh|sshd|networking|systemd-*|dbus|cron|rsyslog|udev|getty*)
                echo "保留系统服务: $service"
                ;;
            *)
                if ask_confirmation "是否禁用服务: $service？"; then
                    systemctl disable "$service" 2>/dev/null || true
                fi
                ;;
        esac
    done
fi

echo "======================================"
echo "安全重置完成！"
echo "建议重启系统以确保所有更改生效"
echo "======================================"

if ask_confirmation "是否立即重启系统？"; then
    echo "系统将在5秒后重启..."
    sleep 5
    reboot
fi