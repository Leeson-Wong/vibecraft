# 阿里云容器镜像服务部署指南

## 镜像信息

```
仓库地址: registry.cn-hangzhou.aliyuncs.com
命名空间: library
镜像名称: vibecraft
用户名: 乐观山里娃

完整地址: registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

---

## 快速开始

### 1. 登录阿里云容器镜像服务

```bash
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com
# 输入密码后回车
```

### 2. 拉取镜像

```bash
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

### 3. 运行容器

```bash
# 本地访问
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 公网访问 - 关键配置！
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://47.96.93.247:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

---

## 使用推送脚本

### Windows (PowerShell)

```powershell
# 基础推送
.\push-aliyun.ps1

# 指定版本标签
.\push-aliyun.ps1 -Tag "v1.0.0"

# 推送到自定义命名空间
.\push-aliyun.ps1 -Namespace "myproject" -Tag "v1.0.0"

# 同时推送 stable 标签
.\push-aliyun.ps1 -PushStable
```

### Linux/Mac (Bash)

```bash
# 添加执行权限
chmod +x push-aliyun.sh

# 基础推送
./push-aliyun.sh

# 指定版本标签
./push-aliyun.sh -t v1.0.0

# 推送到自定义命名空间
./push-aliyun.sh -n myproject -t v1.0.0

# 同时推送 stable 标签
./push-aliyun.sh -s

# 查看帮助
./push-aliyun.sh -h
```

---

## GitHub Actions 自动部署

### 配置 Secrets

在 GitHub 仓库中设置以下 Secrets（Settings → Secrets and variables → Actions）:

| Secret 名称 | 值 |
|------------|-----|
| `ALIYUN_USERNAME` | `乐观山里娃` |
| `ALIYUN_PASSWORD` | 你的阿里云密码 |

### 自动触发构建

推送代码或标签时会自动构建并推送镜像：

```bash
# 推送到 main 分支 - 构建 latest 标签
git push origin main

# 推送版本标签 - 构建版本标签（如 v1.0.0）
git tag v1.0.0
git push origin v1.0.0
```

### 手动触发

在 GitHub 仓库页面：
1. 进入 Actions 标签
2. 选择 "Build and Push Docker Image"
3. 点击 "Run workflow"

---

## 环境变量配置

### 允许的来源（重要！）

| 场景 | ALLOWED_ORIGINS 配置 |
|------|---------------------|
| 仅本地访问 | `http://localhost:4002,http://127.0.0.1:4002` |
| 公网IP访问 | `http://localhost:4002,http://47.96.93.247:4002` |
| 域名访问 | `http://localhost:4002,https://your-domain.com` |
| 多个地址 | `http://localhost:4002,http://IP:4002,https://domain.com` |

### 完整环境变量列表

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `VIBECRAFT_PORT` | 4003 | WebSocket服务端口 |
| `VIBECRAFT_CLIENT_PORT` | 4002 | 前端端口 |
| `ALLOWED_ORIGINS` | localhost | ⚠️ 允许的WebSocket来源 |
| `VIBECRAFT_DEBUG` | false | 调试模式 |
| `VIBECRAFT_TMUX_SESSION` | claude | tmux会话名称 |
| `DEEPGRAM_API_KEY` | - | 语音识别密钥（可选） |

---

## 常见部署场景

### 场景1：阿里云ECS部署

```bash
# 1. 拉取镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 2. 运行容器（使用内网IP）
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://YOUR-ECS-INTERNAL-IP:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 3. 配置安全组开放端口
# 阿里云控制台 → ECS → 安全组 → 添加规则
# 入方向：4002/tcp, 4003/tcp
```

### 场景2：使用Nginx反向代理

```bash
# 1. 运行容器
docker run -d \
  --name vibecraft \
  -p 127.0.0.1:4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="https://your-domain.com" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 2. 配置Nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL证书配置
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:4003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 场景3：多实例部署

```bash
# 实例1 - 开发环境
docker run -d \
  --name vibecraft-dev \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-dev-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 实例2 - 生产环境
docker run -d \
  --name vibecraft-prod \
  -p 8082:4002 \
  -p 8083:4003 \
  -v vibecraft-prod-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="https://your-domain.com" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

---

## 更新和维护

### 更新镜像

```bash
# 1. 停止并删除旧容器
docker stop vibecraft
docker rm vibecraft

# 2. 拉取最新镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 3. 使用相同的volume重新启动
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://47.96.93.247:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

### 备份数据

```bash
# 备份到当前目录
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/vibecraft-backup-$(date +%Y%m%d-%H%M%S).tar.gz /data

# 恢复数据
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/vibecraft-backup-20240202-120000.tar.gz -C /
```

---

## 故障排查

### 问题1：无法拉取镜像

```bash
# 检查登录状态
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com

# 检查网络连接
ping registry.cn-hangzhou.aliyuncs.com
```

### 问题2：WebSocket连接失败

确保 `ALLOWED_ORIGINS` 包含你的访问地址：
```bash
# 检查容器环境变量
docker exec vibecraft env | grep ALLOWED_ORIGINS

# 重新创建容器并设置正确的ALLOWED_ORIGINS
docker stop vibecraft && docker rm vibecraft
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://YOUR-ACCESS-ADDRESS" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

### 问题3：镜像标签问题

查看可用标签：
```bash
# 登录后查看
docker search registry.cn-hangzhou.aliyuncs.com/library/vibecraft

# 或使用 curl
curl -X GET "https://cr.console.aliyun.com/repository/api/tags/library/vibecraft"
```

---

## 镜像版本管理

推荐使用版本标签而非 `latest`：

```bash
# 使用特定版本
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:v1.0.0
docker run -d ... registry.cn-hangzhou.aliyuncs.com/library/vibecraft:v1.0.0

# 使用 stable 标签（推荐生产环境）
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:stable
docker run -d ... registry.cn-hangzhou.aliyuncs.com/library/vibecraft:stable
```

---

## 相关链接

- [阿里云容器镜像服务控制台](https://cr.console.aliyun.com/)
- [容器镜像服务文档](https://help.aliyun.com/product/60716.html)
- [Docker 官方文档](https://docs.docker.com/)

---

## 快速命令参考

```bash
# 登录
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com

# 拉取
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 运行（公网访问）
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://YOUR-IP:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 查看日志
docker logs -f vibecraft

# 停止
docker stop vibecraft

# 启动
docker start vibecraft

# 重启
docker restart vibecraft

# 删除
docker rm -f vibecraft
```
