#!/bin/bash

# build.sh - 构建和推送Docker镜像脚本

# 配置变量
DOCKER_USERNAME="hunterluo"
IMAGE_NAME="shortlink-go"
TAG="latest"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "开始构建短链服务Docker镜像 (Go版本)..."

# 检查必要文件
if [ ! -f "main.go" ]; then
    echo "错误: main.go 文件不存在"
    exit 1
fi

if [ ! -f "Dockerfile" ]; then
    echo "错误: Dockerfile 文件不存在"
    exit 1
fi

# 构建Docker镜像（多平台支持）
echo "构建镜像: ${FULL_IMAGE_NAME}"

read -p "是否构建多平台镜像 (linux/amd64,linux/arm64)? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker buildx build --platform linux/amd64,linux/arm64 -t ${FULL_IMAGE_NAME} --push .
    echo "多平台镜像构建并推送成功!"
else
    docker build -t ${FULL_IMAGE_NAME} .
    if [ $? -ne 0 ]; then
        echo "错误: Docker镜像构建失败"
        exit 1
    fi
    echo "镜像构建成功!"

    # 询问是否推送
    read -p "是否推送镜像到Docker Hub? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "登录Docker Hub..."
        docker login

        if [ $? -eq 0 ]; then
            echo "推送镜像..."
            docker push ${FULL_IMAGE_NAME}

            if [ $? -eq 0 ]; then
                echo "镜像推送成功!"
                echo "拉取命令: docker pull ${FULL_IMAGE_NAME}"
            else
                echo "错误: 镜像推送失败"
                exit 1
            fi
        else
            echo "错误: Docker Hub登录失败"
            exit 1
        fi
    fi
fi

echo "完成!"
