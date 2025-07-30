# 大麦网项目快速部署指南

## 🚀 一键部署

### 前置要求
- Docker 20.0+
- Docker Compose 2.0+
- Java 17+
- Maven 3.8+
- Node.js 16+ (前端编译)

### 快速开始

1. **克隆项目**
```bash
git clone <项目地址>
cd damai
```

2. **一键部署**
```bash
# 开发环境部署
./deploy.sh dev

# 测试环境部署
./deploy.sh test

# 生产环境部署
./deploy.sh prod
```

3. **访问应用**
- 前端地址: http://localhost
- API网关: http://localhost:6085
- Nacos控制台: http://localhost:8848/nacos (nacos/nacos)
- Sentinel控制台: http://localhost:8082
- API文档: http://localhost:6085/doc.html

## ⚡ 快速操作

### 启动项目（已编译）
```bash
./scripts/start.sh
```

### 停止项目
```bash
./scripts/stop.sh
```

### 查看日志
```bash
# 查看所有服务状态
docker-compose ps

# 查看特定服务日志
docker-compose logs -f gateway-service
docker-compose logs -f user-service

# 查看所有服务日志
docker-compose logs -f
```

### 重启服务
```bash
# 重启特定服务
docker-compose restart user-service

# 重启所有服务
docker-compose restart
```

## 🔧 开发调试

### 单独启动基础设施
```bash
# 只启动数据库和中间件
docker-compose up -d mysql-master redis-master-1 nacos kafka elasticsearch
```

### 本地开发模式
1. 启动基础设施服务
2. 修改各服务的 `application-local.yml` 配置
3. 在IDE中启动具体的服务

### 数据库管理
```bash
# 连接MySQL主库
docker exec -it damai-mysql-master mysql -uroot -proot

# 连接Redis
docker exec -it damai-redis-master-1 redis-cli

# 备份数据库
docker exec damai-mysql-master mysqldump -uroot -proot --all-databases > backup.sql
```

## 📊 监控和运维

### 健康检查
```bash
# 检查所有服务健康状态
curl http://localhost:6085/actuator/health

# 检查具体服务
curl http://localhost:6082/actuator/health  # 用户服务
curl http://localhost:6083/actuator/health  # 订单服务
```

### 性能监控
- Spring Boot Admin: http://localhost:6087/admin
- Actuator端点: http://localhost:6085/actuator
- JVM指标: http://localhost:6085/actuator/metrics

### 服务注册状态
- Nacos服务列表: http://localhost:8848/nacos/#/serviceManagement

## 🐛 常见问题

### 1. 端口冲突
检查端口占用：
```bash
netstat -tlnp | grep :3306
netstat -tlnp | grep :6379
```

修改 `docker-compose.yml` 中的端口映射。

### 2. 内存不足
调整Docker内存限制或服务副本数：
```bash
# 减少服务副本
docker-compose up -d --scale user-service=1
```

### 3. 服务启动失败
查看具体服务日志：
```bash
docker-compose logs service-name
```

常见原因：
- 数据库连接失败
- 注册中心连接超时
- 配置文件错误

### 4. 数据库初始化失败
手动执行SQL脚本：
```bash
docker exec -i damai-mysql-master mysql -uroot -proot < sql/cloud/1_damai_cloud_create_database.sql
```

## 🚀 生产部署建议

### 1. 资源配置
- CPU: 8核心+
- 内存: 16GB+
- 磁盘: SSD 200GB+
- 网络: 1Gbps+

### 2. 安全配置
- 修改默认密码
- 配置防火墙规则
- 启用SSL证书
- 配置访问日志

### 3. 高可用部署
- 数据库主从复制
- Redis哨兵模式
- 应用多实例负载均衡
- Nginx反向代理

### 4. 备份策略
- 数据库定时备份
- 配置文件版本管理
- 应用日志轮转
- 监控告警配置

## 📞 技术支持

如遇到部署问题，请提供以下信息：
1. 操作系统版本
2. Docker版本
3. 错误日志
4. 服务状态 (`docker-compose ps`)

---

更多详细信息请参考 [deployment-guide.md](deployment-guide.md)