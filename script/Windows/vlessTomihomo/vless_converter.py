#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VLESS链接转换为YAML配置格式的脚本
"""

import urllib.parse
import re

def parse_vless_url(vless_url):
    """
    解析VLESS URL并转换为YAML格式配置
    """
    # 移除vless://前缀
    if not vless_url.startswith('vless://'):
        raise ValueError("不是有效的VLESS URL")
    
    url_content = vless_url[8:]  # 移除 'vless://' 前缀
    
    # 分离用户信息和参数
    if '@' not in url_content:
        raise ValueError("URL格式错误：缺少@符号")
    
    user_part, server_part = url_content.split('@', 1)
    uuid = user_part
    
    # 分离服务器地址和参数
    if '?' not in server_part:
        raise ValueError("URL格式错误：缺少参数")
    
    server_info, params_part = server_part.split('?', 1)
    
    # 解析服务器地址和端口
    if ':' not in server_info:
        raise ValueError("URL格式错误：缺少端口")
    
    server, port = server_info.rsplit(':', 1)
    
    # 解析参数
    params = urllib.parse.parse_qs(params_part)
    
    # 提取名称（从fragment中）
    name = "Unknown"
    if '#' in params_part:
        name = urllib.parse.unquote(params_part.split('#')[1])
    
    # 构建YAML配置
    config = {
        'name': name,
        'server': server,
        'port': int(port),
        'type': 'vless',
        'uuid': uuid,
        'tls': True,
        'tfo': False,
        'skip-cert-verify': params.get('allowInsecure', ['0'])[0] == '1',
        'network': params.get('type', ['tcp'])[0]
    }
    
    # 添加flow参数
    if 'flow' in params:
        config['flow'] = params['flow'][0]
    
    # 添加servername
    if 'sni' in params:
        config['servername'] = params['sni'][0]
    
    # 添加client-fingerprint
    if 'fp' in params:
        config['client-fingerprint'] = params['fp'][0]
    
    # 添加reality配置
    if 'security' in params and params['security'][0] == 'reality':
        reality_opts = {}
        if 'pbk' in params:
            reality_opts['public-key'] = params['pbk'][0]
        if 'sid' in params:
            reality_opts['short-id'] = params['sid'][0]
        if reality_opts:
            config['reality-opts'] = reality_opts
    
    return config

def format_yaml_config(config):
    """
    将配置字典格式化为YAML字符串
    """
    yaml_lines = []
    yaml_lines.append(f"- name: {config['name']}")
    yaml_lines.append(f"  server: {config['server']}")
    yaml_lines.append(f"  port: {config['port']}")
    
    if 'reality-opts' in config:
        yaml_lines.append("  reality-opts:")
        for key, value in config['reality-opts'].items():
            if isinstance(value, str) and not value.isdigit():
                yaml_lines.append(f"    {key}: \"{value}\"")
            else:
                yaml_lines.append(f"    {key}: {value}")
    
    if 'client-fingerprint' in config:
        yaml_lines.append(f"  client-fingerprint: {config['client-fingerprint']}")
    
    yaml_lines.append(f"  type: {config['type']}")
    yaml_lines.append(f"  uuid: {config['uuid']}")
    yaml_lines.append(f"  tls: {str(config['tls']).lower()}")
    yaml_lines.append(f"  tfo: {str(config['tfo']).lower()}")
    
    if 'flow' in config:
        yaml_lines.append(f"  flow: {config['flow']}")
    
    yaml_lines.append(f"  skip-cert-verify: {str(config['skip-cert-verify']).lower()}")
    
    if 'servername' in config:
        yaml_lines.append(f"  servername: {config['servername']}")
    
    yaml_lines.append(f"  network: {config['network']}")
    
    return '\n'.join(yaml_lines)

def main():
    # 示例VLESS URL
    vless_url = "vless://fb285050-89de-4195-9468-926dab67044d@vps-aligz.tionmon.com:11443?encryption=none&flow=xtls-rprx-vision-udp443&security=reality&sni=yahoo.com&fp=chrome&pbk=r4eWwyniMAsxMRvrIspCPdkUcg9i3JfDKsWG7a6JLE8&sid=e1d159c2d3a4a7&spx=%2F&allowInsecure=1&type=tcp&headerType=none#T5-T1"
    
    try:
        # 解析VLESS URL
        config = parse_vless_url(vless_url)
        
        # 格式化为YAML
        yaml_output = format_yaml_config(config)
        
        print("转换结果:")
        print(yaml_output)
        
        # 保存到文件
        with open('vless_config.yaml', 'w', encoding='utf-8') as f:
            f.write(yaml_output)
        
        print("\n配置已保存到 vless_config.yaml 文件")
        
    except Exception as e:
        print(f"转换失败: {e}")

if __name__ == "__main__":
    main()