# 大麦网高并发项目部署指南

## 部署架构概览

### 技术栈
- **后端**: Spring Boot 3.3.0 + Spring Cloud 2023.0.2 + Spring Cloud Alibaba
- **数据库**: MySQL 8.0 (分库分表)
- **缓存**: Redis 7.0
- **消息队列**: Kafka 3.5
- **搜索引擎**: Elasticsearch 8.0
- **注册中心**: Nacos 2.0.3
- **流量控制**: Sentinel
- **前端**: Vue 3 + Element Plus

### 服务清单
1. **damai-gateway-service** (网关服务) - 端口: 6085
2. **damai-user-service** (用户服务) - 端口: 6082
3. **damai-order-service** (订单服务) - 端口: 6083
4. **damai-pay-service** (支付服务) - 端口: 6084
5. **damai-program-service** (节目服务) - 端口: 6081
6. **damai-base-data-service** (基础数据服务) - 端口: 6086
7. **damai-admin-service** (管理服务) - 端口: 6087
8. **damai-customize-service** (定制服务) - 端口: 6088
9. **Vue3前端** - 端口: 80

## 部署方式

### 方式一：Docker Compose (推荐)

#### 1. 环境准备
```bash
# 安装Docker和Docker Compose
curl -fsSL https://get.docker.com | bash -s docker
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 创建项目目录
mkdir -p /opt/damai
cd /opt/damai
```

#### 2. 数据库初始化
```bash
# 先启动MySQL
docker-compose up -d mysql-master mysql-slave

# 等待MySQL启动完成
sleep 30

# 执行数据库初始化脚本
docker exec -i mysql-master mysql -uroot -proot < sql/cloud/1_damai_cloud_create_database.sql
docker exec -i mysql-master mysql -uroot -proot damai_user_0 < sql/cloud/damai_user_0.sql
docker exec -i mysql-master mysql -uroot -proot damai_user_1 < sql/cloud/damai_user_1.sql
# ... 执行其他数据库脚本
```

#### 3. 启动基础设施
```bash
# 启动基础服务
docker-compose up -d redis-cluster nacos kafka elasticsearch sentinel
```

#### 4. 编译打包应用
```bash
# 后端打包
mvn clean package -DskipTests

# 前端打包
cd vue3
npm install
npm run build
```

#### 5. 启动应用服务
```bash
# 按顺序启动服务
docker-compose up -d gateway-service
sleep 10
docker-compose up -d user-service order-service pay-service program-service
sleep 10
docker-compose up -d base-data-service admin-service customize-service
sleep 10
docker-compose up -d frontend
```

### 方式二：Kubernetes部署

#### 1. 创建命名空间
```bash
kubectl create namespace damai
```

#### 2. 部署基础设施
```bash
# 部署MySQL集群
kubectl apply -f k8s/mysql/

# 部署Redis集群
kubectl apply -f k8s/redis/

# 部署Nacos
kubectl apply -f k8s/nacos/

# 部署其他基础设施
kubectl apply -f k8s/kafka/
kubectl apply -f k8s/elasticsearch/
```

#### 3. 部署应用服务
```bash
# 部署网关
kubectl apply -f k8s/gateway/

# 部署业务服务
kubectl apply -f k8s/services/

# 部署前端
kubectl apply -f k8s/frontend/
```

### 方式三：传统服务器部署

#### 1. 环境安装
```bash
# Java 17
wget https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz
tar -xzf jdk-17_linux-x64_bin.tar.gz
sudo mv jdk-17.0.8 /opt/jdk17
echo 'export JAVA_HOME=/opt/jdk17' >> ~/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc
source ~/.bashrc

# MySQL 8.0
sudo apt update
sudo apt install mysql-server-8.0

# Redis 7.0
wget http://download.redis.io/redis-stable.tar.gz
tar xzf redis-stable.tar.gz
cd redis-stable
make && sudo make install

# Nacos
wget https://github.com/alibaba/nacos/releases/download/2.0.3/nacos-server-2.0.3.tar.gz
tar -xzf nacos-server-2.0.3.tar.gz

# Kafka
wget https://downloads.apache.org/kafka/2.13-3.5.0/kafka_2.13-3.5.0.tgz
tar -xzf kafka_2.13-3.5.0.tgz

# Elasticsearch
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.9.0-linux-x86_64.tar.gz
tar -xzf elasticsearch-8.9.0-linux-x86_64.tar.gz

# Nginx
sudo apt install nginx
```

#### 2. 服务配置和启动
参见各组件详细配置文档。

## 环境配置

### 开发环境 (dev)
- 单机部署，用于开发调试
- 数据库: 单实例MySQL
- Redis: 单实例
- 所有服务部署在同一台机器

### 测试环境 (test)
- 模拟生产环境，用于功能测试
- 数据库: 主从复制
- Redis: 哨兵模式
- 基础设施和应用分离部署

### 生产环境 (prod)
- 高可用架构，用于正式服务
- 数据库: 主从复制 + 分库分表
- Redis: 集群模式
- Nacos: 集群模式
- Kafka: 集群模式
- 应用: 多实例负载均衡

## 监控和运维

### 健康检查
- Spring Boot Actuator: 应用健康状态
- Nacos: 服务注册状态
- Sentinel: 流量控制状态

### 日志管理
- ELK Stack: 集中日志管理
- 日志级别: INFO (生产), DEBUG (开发)
- 日志轮转: 按天轮转，保留30天

### 性能监控
- Micrometer + Prometheus: 指标收集
- Grafana: 指标可视化
- JVM监控: 内存、GC、线程

### 安全配置
- 数据库连接加密
- Redis密码认证
- API接口鉴权
- 敏感数据加密存储

## 常见问题

### 1. 服务启动失败
- 检查端口是否被占用
- 检查配置文件中的数据库连接
- 查看服务日志排查具体错误

### 2. 数据库连接失败
- 确认数据库服务已启动
- 检查数据库用户权限
- 验证网络连通性

### 3. 注册中心连接失败
- 确认Nacos服务状态
- 检查网络连通性
- 验证用户名密码

### 4. 前端访问异常
- 检查Nginx配置
- 确认后端服务状态
- 检查跨域配置

## 扩容指南

### 水平扩容
- 数据库: 增加分片
- 应用服务: 增加实例
- Redis: 扩容集群节点

### 垂直扩容
- 增加服务器CPU/内存
- 调整JVM堆内存配置
- 优化数据库配置参数

## 备份恢复

### 数据备份
- MySQL: 定时全量+增量备份
- Redis: RDB+AOF备份
- 配置文件: 版本控制管理

### 灾难恢复
- 数据库: 主从切换
- 应用: 蓝绿部署
- 回滚策略: 版本回退