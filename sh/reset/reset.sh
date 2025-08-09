#!/bin/bash

# Debian 12 系统重置脚本
# 警告：此脚本会删除大量服务和数据，请谨慎使用！
# 建议在执行前备份重要数据

set -e

echo "======================================"
echo "Debian 12 系统重置脚本"
echo "警告：此操作将删除大量服务和数据！"
echo "======================================"

# 确认操作
read -p "确定要继续吗？输入 'YES' 确认: " confirm
if [ "$confirm" != "YES" ]; then
    echo "操作已取消"
    exit 1
fi

echo "开始系统重置..."

# 1. 停止并删除Docker相关服务
echo "[1/15] 清理Docker..."
if command -v docker &> /dev/null; then
    # 停止所有容器
    docker stop $(docker ps -aq) 2>/dev/null || true
    # 删除所有容器
    docker rm $(docker ps -aq) 2>/dev/null || true
    # 删除所有镜像
    docker rmi $(docker images -q) 2>/dev/null || true
    # 删除所有卷
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    # 删除所有网络
    docker network rm $(docker network ls -q) 2>/dev/null || true
    # 停止Docker服务
    systemctl stop docker 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true
    # 卸载Docker
    apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    # 删除Docker目录
    rm -rf /var/lib/docker
    rm -rf /etc/docker
    rm -rf ~/.docker
fi

# 2. 清理Snap包
echo "[2/15] 清理Snap包..."
if command -v snap &> /dev/null; then
    snap list | awk 'NR>1 {print $1}' | xargs -I {} snap remove {} 2>/dev/null || true
    systemctl stop snapd 2>/dev/null || true
    systemctl disable snapd 2>/dev/null || true
    apt-get remove --purge -y snapd 2>/dev/null || true
    rm -rf /snap
    rm -rf /var/snap
    rm -rf /var/lib/snapd
fi

# 3. 清理Flatpak应用
echo "[3/15] 清理Flatpak应用..."
if command -v flatpak &> /dev/null; then
    flatpak uninstall --all -y 2>/dev/null || true
    apt-get remove --purge -y flatpak 2>/dev/null || true
    rm -rf /var/lib/flatpak
    rm -rf ~/.local/share/flatpak
fi

# 4. 清理Web服务器
echo "[4/15] 清理Web服务器..."
for service in apache2 nginx lighttpd; do
    systemctl stop $service 2>/dev/null || true
    systemctl disable $service 2>/dev/null || true
    apt-get remove --purge -y $service 2>/dev/null || true
done
rm -rf /var/www
rm -rf /etc/apache2
rm -rf /etc/nginx
rm -rf /etc/lighttpd

# 5. 清理数据库服务
echo "[5/15] 清理数据库服务..."
for service in mysql mariadb-server postgresql redis-server mongodb; do
    systemctl stop $service 2>/dev/null || true
    systemctl disable $service 2>/dev/null || true
    apt-get remove --purge -y $service 2>/dev/null || true
done
rm -rf /var/lib/mysql
rm -rf /var/lib/postgresql
rm -rf /var/lib/redis
rm -rf /var/lib/mongodb
rm -rf /etc/mysql
rm -rf /etc/postgresql

# 6. 清理开发工具和语言环境
echo "[6/15] 清理开发工具..."
apt-get remove --purge -y nodejs npm python3-pip golang-go openjdk-* 2>/dev/null || true
rm -rf ~/.npm
rm -rf ~/.pip
rm -rf ~/.go
rm -rf ~/.java
rm -rf /usr/local/go

# 7. 清理虚拟化软件
echo "[7/15] 清理虚拟化软件..."
for service in virtualbox-* qemu-* libvirt-*; do
    systemctl stop $service 2>/dev/null || true
    systemctl disable $service 2>/dev/null || true
    apt-get remove --purge -y $service 2>/dev/null || true
done
rm -rf /var/lib/libvirt
rm -rf ~/.VirtualBox

# 8. 清理网络服务
echo "[8/15] 清理网络服务..."
for service in openvpn strongswan wireguard; do
    systemctl stop $service 2>/dev/null || true
    systemctl disable $service 2>/dev/null || true
    apt-get remove --purge -y $service 2>/dev/null || true
done
rm -rf /etc/openvpn
rm -rf /etc/strongswan
rm -rf /etc/wireguard

# 9. 清理桌面环境（如果是服务器版本可跳过）
echo "[9/15] 清理桌面环境..."
read -p "是否清理桌面环境？(y/N): " desktop_confirm
if [ "$desktop_confirm" = "y" ] || [ "$desktop_confirm" = "Y" ]; then
    apt-get remove --purge -y gnome-* kde-* xfce4-* lxde-* mate-* 2>/dev/null || true
    apt-get remove --purge -y xorg x11-* 2>/dev/null || true
    rm -rf /usr/share/gnome
    rm -rf /usr/share/kde4
    rm -rf /usr/share/xfce4
fi

# 10. 清理用户安装的软件
echo "[10/15] 清理用户软件..."
rm -rf /opt/*
rm -rf /usr/local/bin/*
rm -rf /usr/local/lib/*
rm -rf /usr/local/share/*

# 11. 清理日志文件
echo "[11/15] 清理日志文件..."
journalctl --vacuum-time=1d 2>/dev/null || true
rm -rf /var/log/*.log
rm -rf /var/log/*/*.log
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
find /var/log -type f -name "*.old" -delete 2>/dev/null || true

# 12. 清理缓存和临时文件
echo "[12/15] 清理缓存文件..."
apt-get clean
apt-get autoclean
apt-get autoremove -y
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /var/cache/*

# 13. 清理用户目录
echo "[13/15] 清理用户目录..."
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")
        echo "清理用户 $username 的目录..."
        rm -rf "$user_home"/.cache
        rm -rf "$user_home"/.local/share/Trash
        rm -rf "$user_home"/.mozilla
        rm -rf "$user_home"/.chrome
        rm -rf "$user_home"/.config
        rm -rf "$user_home"/Downloads/*
        rm -rf "$user_home"/Documents/*
        rm -rf "$user_home"/Pictures/*
        rm -rf "$user_home"/Videos/*
        rm -rf "$user_home"/Music/*
    fi
done

# 14. 重置网络配置
echo "[14/15] 重置网络配置..."
cp /etc/network/interfaces /etc/network/interfaces.backup 2>/dev/null || true
cat > /etc/network/interfaces << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
EOF

# 15. 清理启动项和服务
echo "[15/15] 清理启动项..."
systemctl list-unit-files --type=service --state=enabled | grep -v "@" | awk '{print $1}' | while read service; do
    case $service in
        ssh|sshd|networking|systemd-*|dbus|cron|rsyslog|udev|getty*)
            echo "保留系统服务: $service"
            ;;
        *)
            echo "禁用服务: $service"
            systemctl disable "$service" 2>/dev/null || true
            ;;
    esac
done

echo "======================================"
echo "系统重置完成！"
echo "建议重启系统以确保所有更改生效"
echo "重启命令: sudo reboot"
echo "======================================"

# 询问是否立即重启
read -p "是否立即重启系统？(y/N): " reboot_confirm
if [ "$reboot_confirm" = "y" ] || [ "$reboot_confirm" = "Y" ]; then
    echo "系统将在5秒后重启..."
    sleep 5
    reboot
fi