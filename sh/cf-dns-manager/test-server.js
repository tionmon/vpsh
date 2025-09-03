#!/usr/bin/env node

/**
 * 简化的测试服务器 - 用于排查启动问题
 * 不依赖外部包，纯 Node.js 实现
 */

const http = require('http');
const path = require('path');
const fs = require('fs');
const url = require('url');

const PORT = process.env.PORT || 3001;

// 简单的 CORS 头部
function setCorsHeaders(res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Auth-Email, X-Auth-Key, X-Requested-With');
}

// 创建服务器
const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    // 设置 CORS 头部
    setCorsHeaders(res);

    // 处理 OPTIONS 请求
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // 健康检查端点
    if (pathname === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            timestamp: new Date().toISOString(),
            message: 'Cloudflare DNS 测试服务器运行正常'
        }));
        return;
    }

    // 根路径 - 提供 HTML 文件
    if (pathname === '/') {
        const htmlPath = path.join(__dirname, 'cf_dns_manager.html');
        
        if (fs.existsSync(htmlPath)) {
            fs.readFile(htmlPath, (err, data) => {
                if (err) {
                    res.writeHead(500);
                    res.end('读取文件错误');
                } else {
                    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
                    res.end(data);
                }
            });
        } else {
            res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
            res.end(`
<!DOCTYPE html>
<html>
<head>
    <title>Cloudflare DNS 管理工具 - 测试服务器</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; padding: 40px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        .success { color: #28a745; font-size: 24px; margin-bottom: 20px; }
        .info { background: #e7f3ff; padding: 15px; border-radius: 6px; margin: 15px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="success">✅ 测试服务器运行成功！</div>
        <div class="info">
            <h3>🎉 恭喜！</h3>
            <p>Cloudflare DNS 管理工具的代理服务器已成功启动。</p>
            <p><strong>访问地址：</strong> http://localhost:${PORT}</p>
            <p><strong>健康检查：</strong> <a href="/health">http://localhost:${PORT}/health</a></p>
        </div>
        <div class="info">
            <h3>📋 下一步：</h3>
            <ol>
                <li>确保 cf_dns_manager.html 文件在同一目录</li>
                <li>配置您的 Cloudflare API Token</li>
                <li>开始管理您的 DNS 记录</li>
            </ol>
        </div>
        <div class="info">
            <h3>🔧 如果遇到问题：</h3>
            <ul>
                <li>运行诊断脚本: <code>./diagnose.sh</code></li>
                <li>查看日志: <code>sudo journalctl -u cf-dns-manager -f</code></li>
                <li>手动启动: <code>node cf-dns-proxy-server.js</code></li>
            </ul>
        </div>
    </div>
</body>
</html>
            `);
        }
        return;
    }

    // API 代理 - 简化版本（仅转发，不处理复杂逻辑）
    if (pathname.startsWith('/api/')) {
        const targetPath = pathname.replace('/api', '/client/v4');
        const targetUrl = `https://api.cloudflare.com${targetPath}`;
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            error: '简化服务器不支持 API 代理',
            message: '请使用完整版代理服务器',
            targetUrl: targetUrl
        }));
        return;
    }

    // 404 处理
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('页面未找到');
});

// 错误处理
server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`❌ 端口 ${PORT} 被占用`);
        console.error('请尝试：');
        console.error(`1. 使用其他端口: PORT=3002 node ${process.argv[1]}`);
        console.error('2. 杀死占用进程: sudo lsof -t -i:' + PORT + ' | xargs sudo kill -9');
        process.exit(1);
    } else {
        console.error('❌ 服务器错误:', err.message);
        process.exit(1);
    }
});

// 启动服务器
server.listen(PORT, () => {
    console.log('🌐 Cloudflare DNS 测试服务器已启动');
    console.log(`📍 访问地址: http://localhost:${PORT}`);
    console.log(`🔗 健康检查: http://localhost:${PORT}/health`);
    console.log('');
    console.log('✅ 如果您看到这条消息，说明 Node.js 环境正常');
    console.log('💡 这是简化版服务器，用于测试基本功能');
    console.log('🔧 如需完整功能，请确保安装了所有依赖');
    console.log('');
    console.log('按 Ctrl+C 停止服务器');
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('\n正在关闭测试服务器...');
    server.close(() => {
        console.log('测试服务器已关闭');
        process.exit(0);
    });
});

process.on('SIGTERM', () => {
    console.log('\n正在关闭测试服务器...');
    server.close(() => {
        console.log('测试服务器已关闭');
        process.exit(0);
    });
});
