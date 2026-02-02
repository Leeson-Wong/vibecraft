# Vibecraft Docker 部署指南

## 快速开始

### 方式一：使用 Docker Compose（推荐）

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 方式二：使用 Docker 命令

```bash
# 1. 构建镜像
docker build -t vibecraft:latest .

# 2. 运行容器
docker run -d \
  --name vibecraft \
  --restart unless-stopped \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS=http://localhost:4002,http://47.96.93.247:4002 \
  vibecraft:latest

# 3. 查看日志
docker logs -f vibecraft
```

---

## 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `VIBECRAFT_PORT` | 4003 | WebSocket/API服务端口 |
| `VIBECRAFT_CLIENT_PORT` | 4002 | 前端服务端口 |
| `ALLOWED_ORIGINS` | localhost | 允许的WebSocket来源（逗号分隔） |
| `VIBECRAFT_DEBUG` | false | 启用调试日志 |
| `VIBECRAFT_TMUX_SESSION` | claude | tmux会话名称 |
| `DEEPGRAM_API_KEY` | - | Deepgram语音转文字API密钥 |

### Volume映射

| 容器路径 | 用途 | 建议映射 |
|----------|------|----------|
| `/home/vibecraft/.vibecraft` | 数据持久化 | ✅ 是 |
| `/app/projects` | Claude工作目录 | ✅ 是（如需访问宿主机代码） |

---

## 公网访问配置

### ⚠️ 重要：解决WebSocket跨域问题

你遇到的错误：
```
Rejected WebSocket connection from origin: http://47.96.93.247:4002
```

这是因为服务器默认只允许 `localhost` 和 `vibecraft.sh` 的连接。

#### 解决方案1：使用环境变量（推荐）

```bash
docker run -d \
  --name vibecraft \
  -p 4002:4002 \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -e ALLOWED_ORIGINS=http://47.96.93.247:4002,https://your-domain.com \
  vibecraft:latest
```

#### 解决方案2：修改源码后重新构建

编辑 `server/index.ts` 中的 `isOriginAllowed` 函数：

```typescript
function isOriginAllowed(origin: string | undefined): boolean {
  if (!origin) return false

  try {
    const url = new URL(origin)

    // 本地开发
    if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') {
      return true
    }

    // 生产环境 - 添加你的域名或IP
    if (url.hostname === 'vibecraft.sh' && url.protocol === 'https:') {
      return true
    }

    // 添加公网IP支持
    if (url.hostname === '47.96.93.247') {
      return true
    }

    // 或者允许所有HTTP（不推荐，仅用于测试）
    // if (url.protocol === 'http:') return true

    return false
  } catch {
    return false
  }
}
```

然后重新构建镜像：
```bash
docker build -t vibecraft:latest .
```

---

## 数据持久化

### 备份数据

```bash
# 备份vibecraft数据
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/vibecraft-backup.tar.gz /data
```

### 恢复数据

```bash
docker run --rm \
  -v vibecraft-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/vibecraft-backup.tar.gz -C /
```

---

## 挂载项目目录

如果你想让容器内的Claude访问宿主机的代码：

```bash
docker run -d \
  --name vibecraft \
  -p 4003:4003 \
  -v vibecraft-data:/home/vibecraft/.vibecraft \
  -v /path/to/your/projects:/app/projects:rw \
  -e ALLOWED_ORIGINS=http://47.96.93.247:4002 \
  vibecraft:latest
```

然后在创建会话时指定工作目录为 `/app/projects/your-project`

---

## 健康检查

容器内置健康检查，每30秒检查一次服务状态：

```bash
# 查看健康状态
docker ps

# 手动触发健康检查
docker exec vibecraft node -e "require('http').get('http://localhost:4003/health', (r) => console.log(r.statusCode))"
```

---

## 常见问题

### 1. WebSocket连接失败

**症状**: 浏览器控制台显示 `WebSocket connection failed`

**解决**:
- 确保防火墙开放4003端口
- 检查 `ALLOWED_ORIGINS` 环境变量包含你的访问地址
- 确认使用 `ws://` 或 `wss://` 正确的协议

### 2. tmux会话丢失

**症状**: 重启容器后Claude会话丢失

**解决**: 这是预期行为，tmux会话是运行时状态。如需持久化，使用 `sessions.json` 的会话管理功能。

### 3. 权限问题

**症状**: 日志显示 `EACCES` 错误

**解决**:
```bash
# 确保volume有正确的权限
docker exec vibecraft chown -R vibecraft:vibecraft /home/vibecraft/.vibecraft
```

---

## 生产部署建议

### 1. 使用反向代理

使用 Nginx 或 Caddy 作为反向代理：

```nginx
# Nginx配置示例
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:4003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. 使用HTTPS

获取SSL证书后更新 `ALLOWED_ORIGINS`:

```bash
-e ALLOWED_ORIGINS=https://your-domain.com
```

### 3. 资源限制

```bash
docker run -d \
  --name vibecraft \
  --memory="512m" \
  --cpus="1.0" \
  ...
```

---

## 推送到镜像仓库

### Docker Hub

```bash
# 登录
docker login

# 标记
docker tag vibecraft:latest your-username/vibecraft:latest

# 推送
docker push your-username/vibecraft:latest
```

### 阿里云容器镜像服务

```bash
# 登录阿里云镜像仓库
docker login --username=your-username registry.cn-hangzhou.aliyuncs.com

# 标记
docker tag vibecraft:latest registry.cn-hangzhou.aliyuncs.com/your-namespace/vibecraft:latest

# 推送
docker push registry.cn-hangzhou.aliyuncs.com/your-namespace/vibecraft:latest
```

### GitHub Container Registry

```bash
# 登录
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 标记
docker tag vibecraft:latest ghcr.io/your-username/vibecraft:latest

# 推送
docker push ghcr.io/your-username/vibecraft:latest
```

告诉你要推送到哪个镜像仓库，我可以为你生成具体的推送命令。
