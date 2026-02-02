# Vibecraft Docker 部署 - 完整指南

## 快速开始（3步部署）

### 方式1：从阿里云镜像部署（推荐）

```bash
# 1. 登录阿里云
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com

# 2. 拉取镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 3. 运行容器（解决WebSocket跨域问题）
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://YOUR-IP:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

**访问地址**: `http://YOUR-IP:4002`

---

### 方式2：使用部署脚本

**Windows (PowerShell)**:
```powershell
.\deploy-docker.ps1 -PublicOrigin "http://47.96.93.247:4002"
```

**Linux/Mac (Bash)**:
```bash
chmod +x deploy-docker.sh
./deploy-docker.sh -o http://47.96.93.247:4002
```

---

## 镜像推送

### 推送到阿里云

```powershell
# Windows
.\push-aliyun.ps1

# Linux/Mac
chmod +x push-aliyun.sh
./push-aliyun.sh
```

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [DEPLOY_GUIDE.md](DEPLOY_GUIDE.md) | 详细部署指南 |
| [ALIYUN_DEPLOY.md](ALIYUN_DEPLOY.md) | 阿里云镜像部署指南 |
| [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) | Docker完整文档 |
| [QUICK_DEPLOY.md](QUICK_DEPLOY.md) | 快速参考卡片 |

---

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ALLOWED_ORIGINS` | localhost | ⚠️ 允许的WebSocket来源（重要！） |
| `VIBECRAFT_PORT` | 4003 | WebSocket服务端口 |
| `VIBECRAFT_CLIENT_PORT` | 4002 | 前端端口 |
| `VIBECRAFT_DEBUG` | false | 调试模式 |

---

## 常用命令

```bash
# 查看日志
docker logs -f vibecraft

# 重启容器
docker restart vibecraft

# 停止容器
docker stop vibecraft

# 删除容器
docker rm -f vibecraft

# 备份数据
docker run --rm -v vibecraft-data:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz /data
```

---

## 阿里云镜像信息

```
仓库: registry.cn-hangzhou.aliyuncs.com
命名空间: library
镜像: vibecraft
标签: latest

完整地址: registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

---

## 自动化部署

项目包含 GitHub Actions 工作流，推送代码或标签时自动构建并推送镜像。

**配置 Secrets**:
- `ALIYUN_USERNAME`: `乐观山里娃`
- `ALIYUN_PASSWORD`: 你的阿里云密码

**触发构建**:
```bash
# 推送main分支 → 构建latest标签
git push origin main

# 推送版本标签 → 构建版本标签
git tag v1.0.0
git push origin v1.0.0
```

---

## 部署脚本参数

### PowerShell (deploy-docker.ps1)

| 参数 | 说明 | 示例 |
|------|------|------|
| `-PublicOrigin` | 公网地址 | `-PublicOrigin "http://IP:PORT"` |
| `-FrontendPort` | 前端端口 | `-FrontendPort 8080` |
| `-WsPort` | WebSocket端口 | `-WsPort 8081` |
| `-Debug` | 启用调试 | `-Debug` |

### Bash (deploy-docker.sh)

| 参数 | 说明 | 示例 |
|------|------|------|
| `-o, --origin` | 公网地址 | `-o http://IP:PORT` |
| `-p, --port` | 前端端口 | `-p 8080` |
| `-w, --ws-port` | WebSocket端口 | `-w 8081` |
| `-d, --debug` | 启用调试 | `-d` |
| `-h, --help` | 显示帮助 | `-h` |

---

## 故障排查

### WebSocket连接被拒绝

**错误**: `Rejected WebSocket connection from origin: http://YOUR-IP:4002`

**解决**: 确保设置 `ALLOWED_ORIGINS` 包含你的访问地址

```bash
-e ALLOWED_ORIGINS="http://localhost:4002,http://YOUR-IP:4002"
```

---

## 完整部署流程示例

```bash
# 1. 克隆仓库
git clone <repository-url>
cd vibecraft

# 2. 构建镜像
docker build -t vibecraft:latest .

# 3. 测试运行（本地访问）
docker run -d \
  --name vibecraft-test \
  -p 4002:4002 \
  -p 4003:4003 \
  vibecraft:latest

# 4. 测试通过后，推送到阿里云
.\push-aliyun.ps1

# 5. 在生产服务器拉取并运行
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://YOUR-IP:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```
