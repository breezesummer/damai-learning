#!/bin/bash

# 大麦网项目快速启动脚本

# 设置脚本错误时退出
set -e

echo "🚀 启动大麦网项目..."

# 检查Docker是否运行
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker未运行，请先启动Docker"
    exit 1
fi

# 启动基础设施服务
echo "📦 启动基础设施服务..."
docker-compose up -d mysql-master redis-master-1 nacos kafka elasticsearch

# 等待服务启动
echo "⏳ 等待基础设施服务启动..."
sleep 60

# 启动应用服务
echo "🔧 启动应用服务..."
docker-compose up -d gateway-service user-service order-service pay-service program-service base-data-service admin-service customize-service

# 等待应用启动
echo "⏳ 等待应用服务启动..."
sleep 30

# 启动前端
echo "🌐 启动前端服务..."
docker-compose up -d frontend

echo "✅ 项目启动完成！"
echo ""
echo "🔗 访问地址："
echo "   前端: http://localhost"
echo "   网关: http://localhost:6085"
echo "   Nacos: http://localhost:8848/nacos"
echo "   API文档: http://localhost:6085/doc.html"
echo ""
echo "📝 使用 'docker-compose logs -f [service-name]' 查看日志"
echo "🛑 使用 'docker-compose down' 停止所有服务"