#!/bin/bash

# 大麦网项目停止脚本

echo "🛑 停止大麦网项目..."

# 停止所有服务
docker-compose down --remove-orphans

echo "✅ 项目已停止"

# 可选：清理数据卷
read -p "是否清理数据卷？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️ 清理数据卷..."
    docker-compose down -v
    echo "✅ 数据卷已清理"
fi

echo "📊 查看剩余容器："
docker ps -a | grep damai || echo "无相关容器"