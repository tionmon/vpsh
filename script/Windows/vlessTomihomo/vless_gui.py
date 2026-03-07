#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VLESS链接批量转换GUI工具
支持批量添加VLESS链接并导出为YAML格式
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, filedialog, messagebox
import urllib.parse
import json
import os
from datetime import datetime

class VlessConverterGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("VLESS链接批量转换工具")
        self.root.geometry("1000x700")
        
        # 存储VLESS链接和转换结果
        self.vless_links = []
        self.converted_configs = []
        
        self.setup_ui()
        
    def setup_ui(self):
        # 创建主框架
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 配置网格权重
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(2, weight=1)
        main_frame.rowconfigure(4, weight=1)
        
        # 标题
        title_label = ttk.Label(main_frame, text="VLESS链接批量转换工具", font=('Arial', 16, 'bold'))
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))
        
        # 输入区域
        input_frame = ttk.LabelFrame(main_frame, text="输入VLESS链接", padding="10")
        input_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        input_frame.columnconfigure(0, weight=1)
        
        # VLESS链接输入框
        ttk.Label(input_frame, text="VLESS链接 (每行一个):").grid(row=0, column=0, sticky=tk.W, pady=(0, 5))
        self.vless_input = scrolledtext.ScrolledText(input_frame, height=8, wrap=tk.WORD)
        self.vless_input.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        # 按钮框架
        button_frame = ttk.Frame(input_frame)
        button_frame.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E))
        
        ttk.Button(button_frame, text="添加链接", command=self.add_links).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(button_frame, text="清空输入", command=self.clear_input).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(button_frame, text="从文件导入", command=self.import_from_file).pack(side=tk.LEFT, padx=(0, 10))
        
        # 链接列表区域
        list_frame = ttk.LabelFrame(main_frame, text="已添加的链接", padding="10")
        list_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10))
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)
        
        # 创建Treeview来显示链接
        columns = ('序号', '名称', '服务器', '端口', '状态')
        self.tree = ttk.Treeview(list_frame, columns=columns, show='headings', height=8)
        
        # 设置列标题和宽度
        self.tree.heading('序号', text='序号')
        self.tree.heading('名称', text='名称')
        self.tree.heading('服务器', text='服务器')
        self.tree.heading('端口', text='端口')
        self.tree.heading('状态', text='状态')
        
        self.tree.column('序号', width=50)
        self.tree.column('名称', width=150)
        self.tree.column('服务器', width=200)
        self.tree.column('端口', width=80)
        self.tree.column('状态', width=100)
        
        # 添加滚动条
        tree_scroll = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscrollcommand=tree_scroll.set)
        
        self.tree.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        tree_scroll.grid(row=0, column=1, sticky=(tk.N, tk.S))
        
        # 链接操作按钮
        link_button_frame = ttk.Frame(list_frame)
        link_button_frame.grid(row=1, column=0, columnspan=2, pady=(10, 0))
        
        ttk.Button(link_button_frame, text="删除选中", command=self.delete_selected).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(link_button_frame, text="清空列表", command=self.clear_list).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(link_button_frame, text="转换配置", command=self.convert_configs).pack(side=tk.LEFT, padx=(0, 10))
        
        # 预览区域
        preview_frame = ttk.LabelFrame(main_frame, text="YAML配置预览", padding="10")
        preview_frame.grid(row=4, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10))
        preview_frame.columnconfigure(0, weight=1)
        preview_frame.rowconfigure(0, weight=1)
        
        self.preview_text = scrolledtext.ScrolledText(preview_frame, height=10, wrap=tk.WORD)
        self.preview_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 导出按钮
        export_frame = ttk.Frame(main_frame)
        export_frame.grid(row=5, column=0, columnspan=3, pady=(10, 0))
        
        ttk.Button(export_frame, text="导出YAML文件", command=self.export_yaml).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(export_frame, text="导出JSON文件", command=self.export_json).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(export_frame, text="复制到剪贴板", command=self.copy_to_clipboard).pack(side=tk.LEFT)
        
    def parse_vless_url(self, vless_url):
        """解析VLESS URL"""
        try:
            if not vless_url.startswith('vless://'):
                raise ValueError("不是有效的VLESS URL")
            
            url_content = vless_url[8:]
            
            if '@' not in url_content:
                raise ValueError("URL格式错误：缺少@符号")
            
            user_part, server_part = url_content.split('@', 1)
            uuid = user_part
            
            if '?' not in server_part:
                raise ValueError("URL格式错误：缺少参数")
            
            server_info, params_part = server_part.split('?', 1)
            
            if ':' not in server_info:
                raise ValueError("URL格式错误：缺少端口")
            
            server, port = server_info.rsplit(':', 1)
            params = urllib.parse.parse_qs(params_part)
            
            # 提取名称
            name = "Unknown"
            if '#' in params_part:
                name = urllib.parse.unquote(params_part.split('#')[1])
            
            # 构建配置
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
            
            # 添加可选参数
            if 'flow' in params:
                config['flow'] = params['flow'][0]
            if 'sni' in params:
                config['servername'] = params['sni'][0]
            if 'fp' in params:
                config['client-fingerprint'] = params['fp'][0]
            
            # Reality配置
            if 'security' in params and params['security'][0] == 'reality':
                reality_opts = {}
                if 'pbk' in params:
                    reality_opts['public-key'] = params['pbk'][0]
                if 'sid' in params:
                    reality_opts['short-id'] = params['sid'][0]
                if reality_opts:
                    config['reality-opts'] = reality_opts
            
            return config, None
            
        except Exception as e:
            return None, str(e)
    
    def add_links(self):
        """添加VLESS链接"""
        content = self.vless_input.get("1.0", tk.END).strip()
        if not content:
            messagebox.showwarning("警告", "请输入VLESS链接")
            return
        
        lines = [line.strip() for line in content.split('\n') if line.strip()]
        added_count = 0
        error_count = 0
        
        for line in lines:
            if line.startswith('vless://'):
                config, error = self.parse_vless_url(line)
                if config:
                    self.vless_links.append({
                        'url': line,
                        'config': config,
                        'status': '已解析'
                    })
                    added_count += 1
                else:
                    self.vless_links.append({
                        'url': line,
                        'config': None,
                        'status': f'错误: {error}'
                    })
                    error_count += 1
        
        self.update_tree()
        messagebox.showinfo("完成", f"添加完成！\n成功: {added_count}\n失败: {error_count}")
        
    def update_tree(self):
        """更新链接列表"""
        # 清空现有项目
        for item in self.tree.get_children():
            self.tree.delete(item)
        
        # 添加新项目
        for i, link_data in enumerate(self.vless_links, 1):
            config = link_data['config']
            if config:
                name = config.get('name', 'Unknown')
                server = config.get('server', 'Unknown')
                port = config.get('port', 'Unknown')
            else:
                name = server = port = 'N/A'
            
            self.tree.insert('', 'end', values=(
                i, name, server, port, link_data['status']
            ))
    
    def delete_selected(self):
        """删除选中的链接"""
        selected_items = self.tree.selection()
        if not selected_items:
            messagebox.showwarning("警告", "请选择要删除的项目")
            return
        
        # 获取选中项目的索引（倒序删除避免索引变化）
        indices = []
        for item in selected_items:
            values = self.tree.item(item, 'values')
            indices.append(int(values[0]) - 1)  # 转换为0基索引
        
        # 倒序删除
        for index in sorted(indices, reverse=True):
            del self.vless_links[index]
        
        self.update_tree()
        messagebox.showinfo("完成", f"已删除 {len(selected_items)} 个项目")
    
    def clear_input(self):
        """清空输入框"""
        self.vless_input.delete("1.0", tk.END)
    
    def clear_list(self):
        """清空链接列表"""
        if messagebox.askyesno("确认", "确定要清空所有链接吗？"):
            self.vless_links.clear()
            self.converted_configs.clear()
            self.update_tree()
            self.preview_text.delete("1.0", tk.END)
    
    def import_from_file(self):
        """从文件导入链接"""
        file_path = filedialog.askopenfilename(
            title="选择文件",
            filetypes=[("文本文件", "*.txt"), ("所有文件", "*.*")]
        )
        
        if file_path:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                self.vless_input.insert(tk.END, content)
                messagebox.showinfo("完成", "文件导入成功")
            except Exception as e:
                messagebox.showerror("错误", f"导入文件失败：{e}")
    
    def convert_configs(self):
        """转换配置并显示预览"""
        if not self.vless_links:
            messagebox.showwarning("警告", "没有可转换的链接")
            return
        
        self.converted_configs = []
        yaml_lines = []
        
        for link_data in self.vless_links:
            config = link_data['config']
            if config:
                self.converted_configs.append(config)
                yaml_lines.append(self.format_yaml_config(config))
        
        if yaml_lines:
            yaml_content = '\n\n'.join(yaml_lines)
            self.preview_text.delete("1.0", tk.END)
            self.preview_text.insert("1.0", yaml_content)
            messagebox.showinfo("完成", f"成功转换 {len(yaml_lines)} 个配置")
        else:
            messagebox.showwarning("警告", "没有有效的配置可转换")
    
    def format_yaml_config(self, config):
        """格式化YAML配置"""
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
    
    def export_yaml(self):
        """导出YAML文件"""
        if not self.converted_configs:
            messagebox.showwarning("警告", "请先转换配置")
            return
        
        file_path = filedialog.asksaveasfilename(
            title="保存YAML文件",
            defaultextension=".yaml",
            filetypes=[("YAML文件", "*.yaml"), ("所有文件", "*.*")],
            initialname=f"vless_configs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.yaml"
        )
        
        if file_path:
            try:
                content = self.preview_text.get("1.0", tk.END).strip()
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                messagebox.showinfo("完成", f"YAML文件已保存到：{file_path}")
            except Exception as e:
                messagebox.showerror("错误", f"保存文件失败：{e}")
    
    def export_json(self):
        """导出JSON文件"""
        if not self.converted_configs:
            messagebox.showwarning("警告", "请先转换配置")
            return
        
        file_path = filedialog.asksaveasfilename(
            title="保存JSON文件",
            defaultextension=".json",
            filetypes=[("JSON文件", "*.json"), ("所有文件", "*.*")],
            initialname=f"vless_configs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        
        if file_path:
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(self.converted_configs, f, ensure_ascii=False, indent=2)
                messagebox.showinfo("完成", f"JSON文件已保存到：{file_path}")
            except Exception as e:
                messagebox.showerror("错误", f"保存文件失败：{e}")
    
    def copy_to_clipboard(self):
        """复制到剪贴板"""
        content = self.preview_text.get("1.0", tk.END).strip()
        if not content:
            messagebox.showwarning("警告", "没有内容可复制")
            return
        
        self.root.clipboard_clear()
        self.root.clipboard_append(content)
        messagebox.showinfo("完成", "内容已复制到剪贴板")

def main():
    root = tk.Tk()
    app = VlessConverterGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()