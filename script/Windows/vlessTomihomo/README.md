# VLESS链接批量转换工具

这是一个用于批量转换VLESS链接为YAML配置格式的图形界面工具。

## 功能特点

- 🖥️ **图形界面操作** - 基于tkinter的直观GUI界面
- 📝 **批量处理** - 支持一次性添加多个VLESS链接
- 🔄 **实时转换** - 即时解析和验证VLESS链接
- 👀 **预览功能** - 转换前可预览YAML配置
- 💾 **多格式导出** - 支持导出YAML和JSON格式
- 📋 **剪贴板支持** - 一键复制配置到剪贴板
- 📁 **文件导入** - 从文本文件批量导入链接

## 使用方法

### 1. 启动程序

```bash
python vless_gui.py
```

### 2. 添加VLESS链接

- **手动输入**: 在"输入VLESS链接"区域粘贴链接，每行一个
- **文件导入**: 点击"从文件导入"按钮，选择包含VLESS链接的文本文件
- **添加到列表**: 点击"添加链接"按钮将链接添加到处理列表

### 3. 管理链接列表

- **查看状态**: 在链接列表中查看每个链接的解析状态
- **删除链接**: 选中不需要的链接，点击"删除选中"
- **清空列表**: 点击"清空列表"删除所有链接

### 4. 转换和导出

- **转换配置**: 点击"转换配置"按钮生成YAML格式配置
- **预览结果**: 在"YAML配置预览"区域查看转换结果
- **导出文件**: 
  - 点击"导出YAML文件"保存为.yaml格式
  - 点击"导出JSON文件"保存为.json格式
- **复制配置**: 点击"复制到剪贴板"将配置复制到系统剪贴板

## 支持的VLESS参数

工具支持解析以下VLESS链接参数：

- **基础参数**: UUID, 服务器地址, 端口
- **传输参数**: 网络类型(tcp/ws等), 流控(flow)
- **安全参数**: TLS, 服务器名称(SNI)
- **Reality协议**: 公钥(public-key), 短ID(short-id)
- **客户端**: 指纹(client-fingerprint)
- **其他**: 跳过证书验证等

## 输出格式示例

```yaml
- name: T5-T1
  server: vps-aligz.tionmon.com
  port: 11443
  reality-opts:
    public-key: "r4eWwyniMAsxMRvrIspCPdkUcg9i3JfDKsWG7a6JLE8"
    short-id: "e1d159c2d3a4a7"
  client-fingerprint: chrome
  type: vless
  uuid: fb285050-89de-4195-9468-926dab67044d
  tls: true
  tfo: false
  flow: xtls-rprx-vision-udp443
  skip-cert-verify: true
  servername: yahoo.com
  network: tcp
```

## 文件说明

- `vless_gui.py` - 图形界面主程序
- `vless_converter.py` - 命令行版本转换工具
- `README.md` - 使用说明文档

## 系统要求

- Python 3.6+
- tkinter (通常随Python安装)
- 支持的操作系统: Windows, macOS, Linux

## 注意事项

1. 请确保输入的VLESS链接格式正确
2. 工具会自动验证链接有效性，无效链接会显示错误状态
3. 导出的配置文件可直接用于支持YAML格式的代理客户端
4. 建议在使用前备份重要的配置文件

## 故障排除

- **链接解析失败**: 检查VLESS链接格式是否正确
- **界面无响应**: 重启程序，检查Python环境
- **文件导出失败**: 确认有写入权限，检查磁盘空间

---

如有问题或建议，请提交Issue或Pull Request。