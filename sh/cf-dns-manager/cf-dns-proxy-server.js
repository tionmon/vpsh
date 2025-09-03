#!/usr/bin/env node

/**
 * Cloudflare DNS 管理工具 - CORS 代理服务器
 * 解决浏览器跨域访问限制问题
 * 
 * 使用方法：
 * 1. 安装依赖：npm install express http-proxy-middleware cors
 * 2. 运行服务器：node cf-dns-proxy-server.js
 * 3. 修改 HTML 文件中的 API 地址为 http://localhost:3001/api
 */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// 启用 CORS
app.use(cors({
    origin: '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Auth-Email', 'X-Auth-Key', 'X-Requested-With']
}));

// 静态文件服务（可选，用于直接访问 HTML 文件）
app.use(express.static(path.join(__dirname)));

// Cloudflare API 代理
app.use('/api', createProxyMiddleware({
    target: 'https://api.cloudflare.com',
    changeOrigin: true,
    pathRewrite: {
        '^/api': '/client/v4'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} -> ${proxyReq.path}`);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log(`[${new Date().toISOString()}] ${proxyRes.statusCode} ${req.url}`);
    },
    onError: (err, req, res) => {
        console.error(`[${new Date().toISOString()}] Proxy Error:`, err.message);
        res.status(500).json({
            success: false,
            errors: [{
                code: 'PROXY_ERROR',
                message: '代理服务器错误: ' + err.message
            }]
        });
    }
}));

// 健康检查端点
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        message: 'Cloudflare DNS 代理服务器运行正常'
    });
});

// 根路径重定向到 HTML 文件
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'cf_dns_manager.html'));
});

// 启动服务器
app.listen(PORT, () => {
    console.log('🌐 Cloudflare DNS 代理服务器已启动');
    console.log(`📍 本地访问地址: http://localhost:${PORT}`);
    console.log(`🔗 API 代理地址: http://localhost:${PORT}/api`);
    console.log(`💡 请将 HTML 文件中的 API 地址修改为: http://localhost:${PORT}/api`);
    console.log('');
    console.log('使用说明：');
    console.log('1. 在浏览器中打开 http://localhost:3001');
    console.log('2. 或者修改 HTML 文件中的 API 地址后使用');
    console.log('3. 按 Ctrl+C 停止服务器');
    console.log('');
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('\n正在关闭代理服务器...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n正在关闭代理服务器...');
    process.exit(0);
});
