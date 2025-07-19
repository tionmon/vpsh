#!/bin/bash

# Debian 12 重置前备份脚本
# 在执行系统重置前，备份重要的配置文件和数据

set -e

echo "======================================"
echo "Debian 12 重置前备份脚本"
echo "======================================"

# 创建备份目录
BACKUP_DIR="/tmp/debian_reset_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "备份目录: $BACKUP_DIR"
echo "开始备份重要配置文件..."

# 1. 备份网络配置
echo "[1/12] 备份网络配置..."
mkdir -p "$BACKUP_DIR/network"
cp -r /etc/network/ "$BACKUP_DIR/network/" 2>/dev/null || true
cp /etc/hosts "$BACKUP_DIR/network/" 2>/dev/null || true
cp /etc/hostname "$BACKUP_DIR/network/" 2>/dev/null || true
cp /etc/resolv.conf "$BACKUP_DIR/network/" 2>/dev/null || true

# 2. 备份SSH配置
echo "[2/12] 备份SSH配置..."
mkdir -p "$BACKUP_DIR/ssh"
cp -r /etc/ssh/ "$BACKUP_DIR/ssh/" 2>/dev/null || true
cp -r ~/.ssh/ "$BACKUP_DIR/ssh/user_ssh/" 2>/dev/null || true

# 3. 备份用户配置
echo "[3/12] 备份用户配置..."
mkdir -p "$BACKUP_DIR/users"
cp /etc/passwd "$BACKUP_DIR/users/" 2>/dev/null || true
cp /etc/group "$BACKUP_DIR/users/" 2>/dev/null || true
cp /etc/shadow "$BACKUP_DIR/users/" 2>/dev/null || true
cp /etc/sudoers "$BACKUP_DIR/users/" 2>/dev/null || true
cp -r /etc/sudoers.d/ "$BACKUP_DIR/users/" 2>/dev/null || true

# 4. 备份系统配置
echo "[4/12] 备份系统配置..."
mkdir -p "$BACKUP_DIR/system"
cp /etc/fstab "$BACKUP_DIR/system/" 2>/dev/null || true
cp /etc/crontab "$BACKUP_DIR/system/" 2>/dev/null || true
cp -r /etc/cron.d/ "$BACKUP_DIR/system/" 2>/dev/null || true
cp -r /var/spool/cron/ "$BACKUP_DIR/system/" 2>/dev/null || true

# 5. 备份APT配置
echo "[5/12] 备份APT配置..."
mkdir -p "$BACKUP_DIR/apt"
cp -r /etc/apt/ "$BACKUP_DIR/apt/" 2>/dev/null || true
dpkg --get-selections > "$BACKUP_DIR/apt/installed_packages.txt" 2>/dev/null || true
apt list --installed > "$BACKUP_DIR/apt/installed_packages_detailed.txt" 2>/dev/null || true

# 6. 备份防火墙配置
echo "[6/12] 备份防火墙配置..."
mkdir -p "$BACKUP_DIR/firewall"
iptables-save > "$BACKUP_DIR/firewall/iptables_rules.txt" 2>/dev/null || true
if command -v ufw &> /dev/null; then
    ufw status verbose > "$BACKUP_DIR/firewall/ufw_status.txt" 2>/dev/null || true
    cp -r /etc/ufw/ "$BACKUP_DIR/firewall/" 2>/dev/null || true
fi

# 7. 备份Web服务器配置
echo "[7/12] 备份Web服务器配置..."
mkdir -p "$BACKUP_DIR/webserver"
cp -r /etc/apache2/ "$BACKUP_DIR/webserver/" 2>/dev/null || true
cp -r /etc/nginx/ "$BACKUP_DIR/webserver/" 2>/dev/null || true
cp -r /etc/lighttpd/ "$BACKUP_DIR/webserver/" 2>/dev/null || true

# 8. 备份数据库配置
echo "[8/12] 备份数据库配置..."
mkdir -p "$BACKUP_DIR/database"
cp -r /etc/mysql/ "$BACKUP_DIR/database/" 2>/dev/null || true
cp -r /etc/postgresql/ "$BACKUP_DIR/database/" 2>/dev/null || true

# 备份MySQL数据库（如果存在）
if command -v mysqldump &> /dev/null && systemctl is-active --quiet mysql 2>/dev/null; then
    echo "备份MySQL数据库..."
    mysqldump --all-databases > "$BACKUP_DIR/database/mysql_all_databases.sql" 2>/dev/null || true
fi

# 备份PostgreSQL数据库（如果存在）
if command -v pg_dumpall &> /dev/null && systemctl is-active --quiet postgresql 2>/dev/null; then
    echo "备份PostgreSQL数据库..."
    sudo -u postgres pg_dumpall > "$BACKUP_DIR/database/postgresql_all_databases.sql" 2>/dev/null || true
fi

# 9. 备份Docker配置
echo "[9/12] 备份Docker配置..."
if command -v docker &> /dev/null; then
    mkdir -p "$BACKUP_DIR/docker"
    cp -r /etc/docker/ "$BACKUP_DIR/docker/" 2>/dev/null || true
    docker images --format "table {{.Repository}}:{{.Tag}}" > "$BACKUP_DIR/docker/images_list.txt" 2>/dev/null || true
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" > "$BACKUP_DIR/docker/containers_list.txt" 2>/dev/null || true
fi

# 10. 备份重要的用户数据
echo "[10/12] 备份用户数据..."
mkdir -p "$BACKUP_DIR/userdata"
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")
        echo "备份用户 $username 的配置文件..."
        mkdir -p "$BACKUP_DIR/userdata/$username"
        
        # 备份shell配置
        cp "$user_home"/.bashrc "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        cp "$user_home"/.bash_profile "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        cp "$user_home"/.profile "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        cp "$user_home"/.zshrc "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        
        # 备份Git配置
        cp "$user_home"/.gitconfig "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        
        # 备份vim配置
        cp "$user_home"/.vimrc "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        cp -r "$user_home"/.vim/ "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
        
        # 备份其他重要配置目录
        cp -r "$user_home"/.config/ "$BACKUP_DIR/userdata/$username/" 2>/dev/null || true
    fi
done

# 11. 备份系统服务列表
echo "[11/12] 备份系统服务信息..."
mkdir -p "$BACKUP_DIR/services"
systemctl list-unit-files --type=service > "$BACKUP_DIR/services/all_services.txt" 2>/dev/null || true
systemctl list-unit-files --type=service --state=enabled > "$BACKUP_DIR/services/enabled_services.txt" 2>/dev/null || true
systemctl list-units --type=service --state=running > "$BACKUP_DIR/services/running_services.txt" 2>/dev/null || true

# 12. 创建恢复脚本
echo "[12/12] 创建恢复脚本..."
cat > "$BACKUP_DIR/restore_guide.sh" << 'EOF'
#!/bin/bash
# 恢复指南脚本
# 此脚本提供了恢复备份配置的基本命令

echo "=== Debian 12 配置恢复指南 ==="
echo "备份位置: $(pwd)"
echo ""
echo "主要恢复命令:"
echo "1. 恢复网络配置:"
echo "   sudo cp -r network/network/* /etc/network/"
echo "   sudo cp network/hosts /etc/"
echo "   sudo cp network/hostname /etc/"
echo ""
echo "2. 恢复SSH配置:"
echo "   sudo cp -r ssh/ssh/* /etc/ssh/"
echo "   cp -r ssh/user_ssh/* ~/.ssh/"
echo ""
echo "3. 恢复APT源:"
echo "   sudo cp -r apt/apt/* /etc/apt/"
echo "   sudo apt update"
echo ""
echo "4. 恢复已安装包列表:"
echo "   sudo dpkg --set-selections < apt/installed_packages.txt"
echo "   sudo apt-get dselect-upgrade"
echo ""
echo "5. 恢复防火墙规则:"
echo "   sudo iptables-restore < firewall/iptables_rules.txt"
echo ""
echo "6. 恢复数据库:"
echo "   # MySQL: mysql < database/mysql_all_databases.sql"
echo "   # PostgreSQL: sudo -u postgres psql < database/postgresql_all_databases.sql"
echo ""
echo "注意: 请根据实际需要选择性恢复配置文件"
EOF

chmod +x "$BACKUP_DIR/restore_guide.sh"

# 创建备份信息文件
cat > "$BACKUP_DIR/backup_info.txt" << EOF
备份时间: $(date)
系统信息: $(uname -a)
主机名: $(hostname)
备份脚本版本: 1.0

备份内容:
- 网络配置 (/etc/network/, /etc/hosts, /etc/hostname, /etc/resolv.conf)
- SSH配置 (/etc/ssh/, ~/.ssh/)
- 用户配置 (/etc/passwd, /etc/group, /etc/shadow, /etc/sudoers)
- 系统配置 (/etc/fstab, crontab配置)
- APT配置和已安装包列表
- 防火墙配置 (iptables, ufw)
- Web服务器配置 (Apache, Nginx, Lighttpd)
- 数据库配置和数据 (MySQL, PostgreSQL)
- Docker配置和镜像列表
- 用户数据和配置文件
- 系统服务列表

恢复方法:
请查看 restore_guide.sh 文件获取详细的恢复指令
EOF

echo "======================================"
echo "备份完成！"
echo "备份位置: $BACKUP_DIR"
echo "备份大小: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "重要文件:"
echo "- backup_info.txt: 备份信息"
echo "- restore_guide.sh: 恢复指南"
echo ""
echo "建议将备份目录复制到安全位置:"
echo "cp -r \"$BACKUP_DIR\" /path/to/safe/location/"
echo "======================================"

# 询问是否压缩备份
read -p "是否压缩备份文件？(y/N): " compress_confirm
if [ "$compress_confirm" = "y" ] || [ "$compress_confirm" = "Y" ]; then
    echo "正在压缩备份文件..."
    tar -czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
    echo "压缩完成: ${BACKUP_DIR}.tar.gz"
    echo "压缩文件大小: $(du -sh "${BACKUP_DIR}.tar.gz" | cut -f1)"
    
    read -p "是否删除原始备份目录？(y/N): " delete_confirm
    if [ "$delete_confirm" = "y" ] || [ "$delete_confirm" = "Y" ]; then
        rm -rf "$BACKUP_DIR"
        echo "原始备份目录已删除"
    fi
fi