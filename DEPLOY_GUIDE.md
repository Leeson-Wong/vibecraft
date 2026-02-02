# Vibecraft 容器化部署指南

## 快速开始

### Windows (PowerShell)

```powershell
# 1. 基础部署 - 仅本地访问
.\deploy-docker.ps1

# 2. 公网访问 - 添加公网IP（解决WebSocket跨域问题）
.\deploy-docker.ps1 -PublicOrigin "http://47.96.93.247:4002"

# 3. 自定义端口
.\deploy-docker.ps1 -PublicOrigin "http://47.96.93.247:4002" -FrontendPort 8080 -WsPort 8081

# 4. 启用调试模式
.\deploy-docker.ps1 -PublicOrigin "http://47.96.93.247:4002" -Debug

# 5. 仅构建镜像
.\deploy-docker.ps1 -BuildOnly
```

### Linux/Mac (Bash)

```bash
# 1. 基础部署 - 仅本地访问
chmod +x deploy-docker.sh
./deploy-docker.sh

# 2. 公网访问 - 添加公网IP
./deploy-docker.sh -o http://47.96.93.247:4002

# 3. 域名访问
./deploy-docker.sh -o https://your-domain.com

# 4. 自定义端口
./deploy-docker.sh -o http://47.96.93.247:4002 -p 8080 -w 8081

# 5. 启用调试
./deploy-docker.sh -o http://47.96.93.247:4002 -d

# 6. 查看帮助
./deploy-docker.sh -h
```

### Docker Compose

```bash
# 1. 复制环境变量模板
cp .env.example .env

# 2. 编辑 .env 文件，修改 ALLOWED_ORIGINS
# ALLOWED_ORIGINS=http://localhost:4002,http://47.96.93.247:4002

# 3. 启动服务
docker-compose up -d

# 4. 查看日志
docker-compose logs -f
```

### 手动 Docker 命令

```bash
# 构建镜像
docker build -t vibecraft:latest .

# 启动容器（本地访问）
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  vibecraft:latest

# 启动容器（公网访问 - 关键！）
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://47.96.93.247:4002" \
  vibecraft:latest
```

---

## 环境变量说明

| 变量名 | 默认值 | 说明 | 示例 |
|--------|--------|------|------|
| `VIBECRAFT_PORT` | 4003 | WebSocket服务端口 | 4003 |
| `VIBECRAFT_CLIENT_PORT` | 4002 | 前端端口 | 4002 |
| `ALLOWED_ORIGINS` | localhost | ⚠️ 允许的WebSocket来源（逗号分隔） | `http://47.96.93.247:4002,https://your-domain.com` |
| `VIBECRAFT_DEBUG` | false | 调试模式 | true |
| `VIBECRAFT_TMUX_SESSION` | claude | tmux会话名称 | claude |
| `DEEPGRAM_API_KEY` | - | 语音识别密钥（可选） | your_key_here |

### ⚠️ 重要：ALLOWED_ORIGINS 配置

这是解决 **WebSocket 跨域被拒绝** 的关键配置！

**格式**:
```
协议://IP:端口,协议://域名
```

**示例**:
```bash
# 仅本地
ALLOWED_ORIGINS=http://localhost:4002,http://127.0.0.1:4002

# 公网IP
ALLOWED_ORIGINS=http://localhost:4002,http://47.96.93.247:4002

# 域名（HTTPS）
ALLOWED_ORIGINS=http://localhost:4002,https://your-domain.com

# 多个地址
ALLOWED_ORIGINS=http://localhost:4002,http://47.96.93.247:4002,https://your-domain.com

# 通配符子域名
ALLOWED_ORIGINS=https://*.example.com
```

---

## 常用运维命令

```bash
# 查看容器状态
docker ps

# 查看实时日志
docker logs -f vibecraft

# 进入容器
docker exec -it vibecraft sh

# 重启容器
docker restart vibecraft

# 停止容器
docker stop vibecraft

# 删除容器
docker rm -f vibecraft

# 查看数据卷
docker volume inspect vibecraft-data

# 备份数据
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/vibecraft-backup-$(date +%Y%m%d).tar.gz /data

# 恢复数据
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/vibecraft-backup-20240202.tar.gz -C /
```

---

## 更新配置

### 修改公网地址

```bash
# 1. 停止并删除旧容器
docker stop vibecraft && docker rm vibecraft

# 2. 重新启动（使用新地址）
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://NEW-IP:4002" \
  vibecraft:latest
```

### 使用部署脚本更简单

```powershell
# Windows
.\deploy-docker.ps1 -PublicOrigin "http://NEW-IP:4002"
```

```bash
# Linux/Mac
./deploy-docker.sh -o http://NEW-IP:4002
```

---

## 故障排查

### 问题1：WebSocket 连接被拒绝

**错误**:
```
Rejected WebSocket connection from origin: http://47.96.93.247:4002
```

**原因**: `ALLOWED_ORIGINS` 未包含你的公网地址

**解决**:
```bash
# 添加你的公网地址
-e ALLOWED_ORIGINS="http://localhost:4002,http://47.96.93.247:4002"
```

### 问题2：容器无法访问宿主机文件

**原因**: 未挂载项目目录

**解决**:
```bash
docker run -d \
  -v /path/to/your/projects:/app/projects:rw \
  ...
```

### 问题3：端口冲突

**错误**: `port is already allocated`

**解决**: 修改端口映射
```bash
# 使用不同的宿主机端口
-p 8080:4002 \
-p 8081:4003 \
```

### 问题4：权限错误

**错误**: `EACCES: permission denied`

**解决**:
```bash
# 修复volume权限
docker exec vibecraft chown -R vibecraft:vibecraft /home/vibecraft/.vibecraft
```

---

## 部署脚本参数

### PowerShell (deploy-docker.ps1)

| 参数 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `-PublicOrigin` | string | 公网访问地址 | `-PublicOrigin "http://47.96.93.247:4002"` |
| `-FrontendPort` | int | 前端端口 | `-FrontendPort 8080` |
| `-WsPort` | int | WebSocket端口 | `-WsPort 8081` |
| `-Debug` | switch | 启用调试 | `-Debug` |
| `-BuildOnly` | switch | 仅构建镜像 | `-BuildOnly` |

### Bash (deploy-docker.sh)

| 参数 | 说明 | 示例 |
|------|------|------|
| `-o, --origin` | 公网访问地址 | `-o http://47.96.93.247:4002` |
| `-p, --port` | 前端端口 | `-p 8080` |
| `-w, --ws-port` | WebSocket端口 | `-w 8081` |
| `-d, --debug` | 启用调试 | `-d` |
| `-b, --build-only` | 仅构建镜像 | `-b` |
| `-h, --help` | 显示帮助 | `-h` |

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `Dockerfile` | Docker镜像构建配置 |
| `docker-compose.yml` | Docker Compose编排文件 |
| `.dockerignore` | 构建排除列表 |
| `.env.example` | 环境变量配置模板 |
| `deploy-docker.ps1` | Windows部署脚本 |
| `deploy-docker.sh` | Linux/Mac部署脚本 |
| `server/index.ts` | 后端代码（已支持ALLOWED_ORIGINS） |
| `DOCKER_DEPLOYMENT.md` | 详细部署文档 |
| `QUICK_DEPLOY.md` | 快速参考卡片 |
| `DEPLOY_GUIDE.md` | 本文件 |

---

## 下一步

### 推送镜像到仓库

告诉我你要推送到哪个容器镜像仓库，我会为你生成推送命令：

1. **Docker Hub** - `docker.io/username/vibecraft`
2. **阿里云** - `registry.cn-hangzhou.aliyuncs.com/namespace/vibecraft`
3. **GitHub** - `ghcr.io/username/vibecraft`
4. **华为云** - `swr.cn-north-4.myhuaweicloud.com/namespace/vibecraft`
5. **其他私有仓库** - 请提供地址
