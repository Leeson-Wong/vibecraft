# Vibecraft 容器化快速参考

## 方案总览

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Container                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Node.js 18 Alpine                                    │  │
│  │  ├─ Frontend (Vite)      :4002                       │  │
│  │  ├─ Backend (WS Server)  :4003                       │  │
│  │  ├─ tmux (会话管理)                                   │  │
│  │  └─ jq (JSON处理)                                    │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Volumes:                                                   │
│  ├─ vibecraft-data → 数据持久化 (events/sessions/tiles)     │
│  └─ /app/projects   → Claude工作目录 (可选)                  │
└─────────────────────────────────────────────────────────────┘

端口映射: 4002(前端) + 4003(WS服务)
环境变量: ALLOWED_ORIGINS (关键!)
```

---

## 快速部署命令

### Windows (PowerShell)
```powershell
# 本地访问
.\deploy-docker.ps1

# 公网访问 (解决WebSocket被拒绝问题)
.\deploy-docker.ps1 -PublicOrigin "http://47.96.93.247:4002"
```

### Linux/Mac (Bash)
```bash
# 本地访问
chmod +x deploy-docker.sh
./deploy-docker.sh

# 公网访问
./deploy-docker.sh "http://47.96.93.247:4002"
```

### Docker Compose
```bash
# 修改 docker-compose.yml 中的 ALLOWED_ORIGINS 后:
docker-compose up -d
```

### 手动 Docker
```bash
docker build -t vibecraft:latest .

docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://47.96.93.247:4002" \
  vibecraft:latest
```

---

## ⚠️ 关键：解决WebSocket跨域

你遇到的错误：
```
Rejected WebSocket connection from origin: http://47.96.93.247:4002
```

**原因**: 服务器默认只允许localhost连接

**解决**: 必须设置 `ALLOWED_ORIGINS` 环境变量

```bash
# 添加你的公网IP或域名
-e ALLOWED_ORIGINS="http://47.96.93.247:4002,https://your-domain.com"
```

支持的格式:
- `http://47.96.93.247:4002` - IP + 端口
- `https://your-domain.com` - 域名
- `*.example.com` - 通配符子域名

---

## 常用运维命令

```bash
# 查看日志
docker logs -f vibecraft

# 进入容器
docker exec -it vibecraft sh

# 重启服务
docker restart vibecraft

# 停止服务
docker stop vibecraft

# 删除容器
docker rm -f vibecraft

# 查看数据卷
docker volume inspect vibecraft-data

# 备份数据
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/vibecraft-backup.tar.gz /data
```

---

## 镜像推送命令

### 阿里云容器镜像服务（推荐）

```bash
# 使用推送脚本（推荐）
.\push-aliyun.ps1                    # Windows
./push-aliyun.sh                     # Linux/Mac

# 手动推送
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com
docker tag vibecraft:latest registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
docker push registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

### Docker Hub
```bash
docker login
docker tag vibecraft:latest username/vibecraft:latest
docker push username/vibecraft:latest
```

### GitHub Container Registry
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker tag vibecraft:latest ghcr.io/username/vibecraft:latest
docker push ghcr.io/username/vibecraft:latest
```

---

## 从阿里云镜像快速部署

```bash
# 1. 登录
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com

# 2. 拉取镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest

# 3. 运行容器
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS="http://localhost:4002,http://YOUR-IP:4002" \
  registry.cn-hangzhou.aliyuncs.com/library/vibecraft:latest
```

---

## 环境变量完整列表

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `VIBECRAFT_PORT` | 4003 | WS服务端口 |
| `VIBECRAFT_CLIENT_PORT` | 4002 | 前端端口 |
| `ALLOWED_ORIGINS` | localhost | ⚠️ 必须配置! |
| `VIBECRAFT_DEBUG` | false | 调试模式 |
| `VIBECRAFT_TMUX_SESSION` | claude | tmux会话名 |
| `DEEPGRAM_API_KEY` | - | 语音识别密钥 |

---

## 网络架构

```
                 ┌─────────────────┐
                 │  Nginx/Caddy    │ (可选反向代理)
                 │  :443 (HTTPS)   │
                 └────────┬────────┘
                          │
                 ┌────────▼────────┐
                 │  Docker Host    │
                 │  :4002 (HTTP)   │
                 │  :4003 (WS)     │
                 └────────┬────────┘
                          │
                 ┌────────▼────────┐
                 │  vibecraft      │
                 │  Container      │
                 │  Frontend + WS  │
                 └─────────────────┘
```

---

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| WebSocket连接失败 | ALLOWED_ORIGINS未配置 | 添加你的公网地址 |
| 容器无法访问宿主机文件 | 未挂载volume | 添加 `-v /path:/app/projects` |
| tmux会话丢失 | 重启容器 | 正常行为，使用sessions持久化 |
| 权限错误 | volume权限问题 | `chown -R vibecraft:vibecraft /home/vibecraft/.vibecraft` |

---

## 文件清单

已创建的Docker相关文件:
- `Dockerfile` - 多阶段构建配置
- `docker-compose.yml` - Compose编排文件
- `.dockerignore` - 构建排除列表
- `deploy-docker.sh` - Linux/Mac部署脚本
- `deploy-docker.ps1` - Windows部署脚本
- `DOCKER_DEPLOYMENT.md` - 详细部署文档

---

## 下一步

告诉我你要推送到哪个镜像仓库，我可以为你生成完整的CI/CD配置和推送脚本:

1. **Docker Hub** - `docker.io/username/vibecraft`
2. **阿里云容器镜像服务** - `registry.cn-hangzhou.aliyuncs.com/namespace/vibecraft`
3. **GitHub Container Registry** - `ghcr.io/username/vibecraft`
4. **华为云SWR** - `swr.cn-north-4.myhuaweicloud.com/namespace/vibecraft`
5. **其他私有仓库** - 请提供仓库地址
