## 1、DD重装脚本
史上最强脚本

```plain
wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh && bash InstallNET.sh -debian 12 -pwd 'password'
```

萌咖大佬的脚本

```plain
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') -d 11 -v 64 -p 密码 -port 端口 -a -firmware
```

beta.gs大佬的脚本

```plain
wget --no-check-certificate -O NewReinstall.sh https://raw.githubusercontent.com/fcurrk/reinstall/master/NewReinstall.sh && chmod a+x NewReinstall.sh && bash NewReinstall.sh
```

DD windows（使用史上最强DD脚本）

```plain
bash <(curl -sSL https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh) -windows 10  -lang "cn"
```

```plain
账户：Administrator
密码：Teddysun.com
```

使用Windows徽标+R快捷键打开运行框，输入powershell运行，弹出powershell命名输入窗口，输入以下命令：irm [https://get.activated.win](https://get.activated.win/) | iex

## 2、综合测试脚本
[bench.sh](http://bench.sh/)

```plain
wget -qO- bench.sh | bash
```

LemonBench

```plain
wget -qO- https://raw.githubusercontent.com/LemonBench/LemonBench/main/LemonBench.sh | bash -s -- --fast
```

融合怪

```plain
bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
```

NodeBench

```plain
bash <(curl -sL https://raw.githubusercontent.com/LloydAsp/NodeBench/main/NodeBench.sh)
```

## 3、性能测试
yabs

```plain
curl -sL yabs.sh | bash
```

跳过网络，测GB5

```plain
curl -sL yabs.sh | bash -s
```

跳过网络和磁盘，测GB5

```plain
curl -sL yabs.sh | bash -s
```

改测GB5不测GB6

```plain
curl -sL yabs.sh | bash -s
```

## 4、流媒体及IP质量测试
最常用版本

```plain
bash <(curl -L -s check.unlock.media)
```

原生检测脚本

```plain
bash <(curl -sL Media.Check.Place)
```

准确度最高

```plain
bash <(curl -L -s https://github.com/1-stream/RegionRestrictionCheck/raw/main/check.sh)
```

IP质量体检脚本

```plain
bash <(curl -sL IP.Check.Place)
```

一键修改解锁DNS

```plain
wget https://raw.githubusercontent.com/Jimmyzxk/DNS-Alice-Unlock/refs/heads/main/dns-unlock.sh && bash dns-unlock.sh
```

## 5、测速脚本
Speedtest

```plain
bash <(curl -sL bash.icu/speedtest)
```

Taier

```plain
bash <(curl -sL res.yserver.ink/taier.sh)
```

hyperspeed

```plain
bash <(curl -Lso- https://bench.im/hyperspeed)
```

全球测速

```plain
wget -qO- nws.sh | bash
```

区域速度测试

```plain
wget -qO- nws.sh | bash -s
```

Ping 和路由测试

```plain
wget -qO- nws.sh | bash -s -- -rt [region]
```

## 6、回程测试
直接显示回程（小白用这个）

```plain
curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
```

回程详细测试（推荐）

```plain
wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
```

```plain
wget https://ghproxy.com/https://raw.githubusercontent.com/vpsxb/testrace/main/testrace.sh -O testrace.sh && bash testrace.sh
```

## 7、功能脚本
添加SWAP

```plain
wget https://www.moerats.com/usr/shell/swap.sh && bash swap.sh
```

Fail2ban

```plain
wget --no-check-certificate https://raw.githubusercontent.com/FunctionClub/Fail2ban/master/fail2ban.sh && bash fail2ban.sh 2>&1 | tee fail2ban.log
```

一键开启BBR，适用于较新的Debian、Ubuntu

```plain
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control
lsmod | grep bbr
```

多功能BBR安装脚本

```plain
wget -N --no-check-certificate "https://gist.github.com/zeruns/a0ec603f20d1b86de6a774a8ba27588f/raw/4f9957ae23f5efb2bb7c57a198ae2cffebfb1c56/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```

锐速/BBRPLUS/BBR2/BBR3

```plain
wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
```

TCP窗口调优

```plain
wget http://sh.nekoneko.cloud/tools.sh -O tools.sh && bash tools.sh
```

添加warp

```plain
wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh [option] [lisence/url/token]
```

25端口开放测试

```plain
telnet smtp.aol.com 25
```

## 8、一键安装常用环境及软件
docker

```plain
bash <(curl -sL 'https:
```

Python

```plain
curl -O https://raw.githubusercontent.com/lx969788249/lxspacepy/master/pyinstall.sh && chmod +x pyinstall.sh && ./pyinstall.sh
```

iperf3

```plain
apt install iperf3
```

realm

```plain
bash <(curl -L https://raw.githubusercontent.com/zhouh047/realm-oneclick-install/main/realm.sh) -i
```

gost

```plain
wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh && chmod +x gost.sh && ./gost.sh
```

极光面板

```plain
bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
```

哪吒监控

```plain
curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh  -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
```

```plain
<script>
window.ShowNetTransfer = true;
window.FixedTopServerName = true;
window.DisableAnimatedMan = true
```

WARP

```plain
wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh
```

Aria2

```plain
wget -N git.io/aria2.sh && chmod +x aria2.sh && ./aria2.sh
```

宝塔

```plain
wget -O install.sh http://v7.hostcli.com/install/install-ubuntu_6.0.sh && sudo bash install.sh
```

PVE虚拟化

```plain
bash <(wget -qO- --no-check-certificate https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/build_backend.sh)
```

Argox

```plain
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh)
```

## 9、综合功能脚本
科技lion

```plain
apt update -y  && apt install -y curl

bash <(curl -sL kejilion.sh)
```

SKY-BOX

```plain
wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
```







