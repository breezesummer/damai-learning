#!/bin/bash

# 大麦网项目一键部署脚本
# 使用方法: ./deploy.sh [environment]
# environment: dev | test | prod (默认: dev)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 命令未找到，请先安装"
        exit 1
    fi
}

# 环境参数
ENVIRONMENT=${1:-dev}
PROJECT_NAME="damai"
DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}

log_info "开始部署 ${PROJECT_NAME} 项目，环境: ${ENVIRONMENT}"

# 1. 检查依赖
log_step "1. 检查环境依赖"
check_command "docker"
check_command "docker-compose"
check_command "mvn"
check_command "java"

# 检查Java版本
JAVA_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed 's/^1\.//' | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt "17" ]; then
    log_error "需要Java 17或更高版本，当前版本: $JAVA_VERSION"
    exit 1
fi

log_info "环境检查通过"

# 2. 停止旧容器
log_step "2. 停止旧容器"
docker-compose down --remove-orphans || true

# 3. 清理旧镜像（可选）
if [ "${CLEAN_IMAGES:-false}" = "true" ]; then
    log_step "3. 清理旧镜像"
    docker system prune -f
    docker image prune -f
fi

# 4. 编译后端项目
log_step "4. 编译后端项目"
log_info "开始Maven编译..."
mvn clean package -DskipTests -T 4C

if [ $? -ne 0 ]; then
    log_error "Maven编译失败"
    exit 1
fi

log_info "后端编译完成"

# 5. 编译前端项目
log_step "5. 编译前端项目"
if [ -d "vue3" ]; then
    cd vue3
    
    # 检查Node.js
    if command -v npm &> /dev/null; then
        log_info "开始前端编译..."
        
        # 设置npm镜像源
        npm config set registry https://registry.npmmirror.com
        
        # 安装依赖
        npm install
        
        # 构建
        npm run build
        
        if [ $? -ne 0 ]; then
            log_error "前端编译失败"
            exit 1
        fi
        
        log_info "前端编译完成"
    else
        log_warn "npm命令未找到，跳过前端编译"
    fi
    
    cd ..
fi

# 6. 创建必要目录
log_step "6. 创建数据目录"
mkdir -p data/{mysql,redis,nacos,kafka,elasticsearch}
mkdir -p logs/{mysql,redis,nacos,kafka,elasticsearch,apps}

# 7. 设置环境变量
log_step "7. 设置环境变量"
export COMPOSE_PROJECT_NAME=${PROJECT_NAME}
export ENVIRONMENT=${ENVIRONMENT}

# 根据环境设置不同的配置
case $ENVIRONMENT in
    "dev")
        export MYSQL_REPLICAS=1
        export REDIS_REPLICAS=1
        export APP_REPLICAS=1
        ;;
    "test")
        export MYSQL_REPLICAS=2
        export REDIS_REPLICAS=3
        export APP_REPLICAS=2
        ;;
    "prod")
        export MYSQL_REPLICAS=2
        export REDIS_REPLICAS=3
        export APP_REPLICAS=3
        ;;
esac

# 8. 启动基础设施
log_step "8. 启动基础设施服务"
log_info "启动MySQL..."
docker-compose up -d mysql-master mysql-slave

log_info "等待MySQL启动..."
sleep 30

# 检查MySQL是否启动成功
until docker exec damai-mysql-master mysqladmin ping -h"localhost" --silent; do
    log_info "等待MySQL启动..."
    sleep 5
done

log_info "MySQL启动成功"

# 初始化数据库
log_info "初始化数据库..."
if [ -f "sql/cloud/1_damai_cloud_create_database.sql" ]; then
    docker exec -i damai-mysql-master mysql -uroot -proot < sql/cloud/1_damai_cloud_create_database.sql
    
    # 执行其他SQL文件
    for sql_file in sql/cloud/damai_*.sql; do
        if [ -f "$sql_file" ]; then
            db_name=$(basename "$sql_file" .sql)
            log_info "导入数据库: $db_name"
            docker exec -i damai-mysql-master mysql -uroot -proot "$db_name" < "$sql_file" || log_warn "导入 $sql_file 失败"
        fi
    done
fi

log_info "启动Redis集群..."
docker-compose up -d redis-master-1 redis-master-2 redis-master-3

log_info "启动Nacos..."
docker-compose up -d nacos

log_info "启动Kafka..."
docker-compose up -d zookeeper kafka

log_info "启动Elasticsearch..."
docker-compose up -d elasticsearch

log_info "启动Sentinel..."
docker-compose up -d sentinel

log_info "等待基础设施服务启动..."
sleep 60

# 9. 启动应用服务
log_step "9. 启动应用服务"
log_info "启动网关服务..."
docker-compose up -d gateway-service

log_info "等待网关服务启动..."
sleep 20

log_info "启动业务服务..."
docker-compose up -d user-service order-service pay-service program-service

log_info "等待业务服务启动..."
sleep 30

log_info "启动其他服务..."
docker-compose up -d base-data-service admin-service customize-service

log_info "等待服务启动..."
sleep 20

# 10. 启动前端
log_step "10. 启动前端服务"
docker-compose up -d frontend

# 11. 健康检查
log_step "11. 执行健康检查"
sleep 30

# 检查服务状态
services=("gateway-service" "user-service" "order-service" "pay-service" "program-service" "base-data-service" "admin-service" "customize-service" "frontend")

for service in "${services[@]}"; do
    if docker-compose ps | grep -q "damai-$service.*Up"; then
        log_info "✓ $service 启动成功"
    else
        log_warn "✗ $service 启动失败或未运行"
    fi
done

# 12. 显示访问信息
log_step "12. 部署完成"
log_info "==========================================="
log_info "大麦网项目部署完成！"
log_info "环境: $ENVIRONMENT"
log_info "==========================================="
log_info "访问地址:"
log_info "  前端地址: http://localhost"
log_info "  网关地址: http://localhost:6085"
log_info "  Nacos控制台: http://localhost:8848/nacos"
log_info "  Sentinel控制台: http://localhost:8082"
log_info "  API文档: http://localhost:6085/doc.html"
log_info "==========================================="
log_info "数据库信息:"
log_info "  MySQL主库: localhost:3306"
log_info "  MySQL从库: localhost:3307"
log_info "  Redis: localhost:6379"
log_info "  用户名: root, 密码: root"
log_info "==========================================="

# 显示服务状态
log_info "服务状态:"
docker-compose ps

log_info "部署脚本执行完成！"
log_info "如需查看日志，使用: docker-compose logs -f [service-name]"
log_info "如需停止服务，使用: docker-compose down"