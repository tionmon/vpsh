@echo off
chcp 65001 >nul
echo.
echo ========================================
echo   Cloudflare DNS 管理工具代理服务器
echo ========================================
echo.

REM 检查是否安装了 Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 错误：未检测到 Node.js
    echo.
    echo 请先安装 Node.js：
    echo 1. 访问 https://nodejs.org/
    echo 2. 下载并安装最新 LTS 版本
    echo 3. 重新运行此脚本
    echo.
    pause
    exit /b 1
)

echo ✅ Node.js 已安装
node --version

REM 检查是否安装了依赖
if not exist "node_modules" (
    echo.
    echo 📦 正在安装依赖包...
    echo.
    npm install
    if %errorlevel% neq 0 (
        echo.
        echo ❌ 依赖安装失败，请检查网络连接
        pause
        exit /b 1
    )
)

echo.
echo 🚀 启动代理服务器...
echo.
echo 💡 启动后请在浏览器中访问：http://localhost:3001
echo 💡 按 Ctrl+C 停止服务器
echo.

REM 启动服务器
node cf-dns-proxy-server.js

pause
