# 阿里云容器镜像服务配置指南

## 问题：GitHub Actions 推送失败

```
insufficient_scope: authorization failed
```

**原因**：阿里云需要使用**访问令牌**而不是登录密码。

---

## 解决方案

### 步骤1：创建阿里云访问令牌

1. 登录 [阿里云控制台](https://cr.console.aliyun.com/)
2. 点击右上角头像 → **访问凭据**
3. 点击 **设置Registry登录密码**
4. 或者使用 **AccessKey**：

   - 进入 [AccessKey管理](https://ram.console.aliyun.com/manage/ak)
   - 创建新的AccessKey（建议创建RAM子用户）
   - 权限：`AliyunContainerRegistryFullAccess`

### 步骤2：更新 GitHub Secrets

进入：`Settings → Secrets and variables → Actions → Repository secrets`

更新或添加以下 Secrets：

| Secret名称 | 值 | 说明 |
|------------|-----|------|
| `ALIYUN_USERNAME` | `乐观山里娃` 或你的阿里云账号 | 固定值 |
| `ALIYUN_PASSWORD` | **访问令牌/AccessKey** | 不是登录密码！ |

⚠️ **重要**：使用以下之一作为密码：
- Registry登录密码（在容器镜像服务控制台设置）
- RAM用户的AccessKey Secret（推荐）

### 步骤3：验证命名空间

在阿里云控制台确认命名空间存在：
1. 访问 [命名空间列表](https://cr.console.aliyun.com/namespace)
2. 检查 `library` 命名空间是否存在
3. 如不存在，创建命名空间或使用默认的个人命名空间

**推荐使用个人命名空间**：
- 修改 `.github/workflows/docker-publish.yml` 中的 `NAMESPACE`
- 或在 GitHub Secrets 中添加 `NAMESPACE` 变量覆盖

### 步骤4：重新触发构建

1. 进入 GitHub 仓库的 **Actions** 标签
2. 选择 **Build and Push Docker Image**
3. 点击 **Run workflow** → **Run workflow**

---

## 替代方案：使用个人命名空间

如果 `library` 命名空间不可用，修改为你的个人命名空间：

### 方法1：修改 workflow 文件

编辑 `.github/workflows/docker-publish.yml`:

```yaml
env:
  NAMESPACE: your-namespace  # 改成你的命名空间
```

### 方法2：使用 Secret 覆盖

在 GitHub Secrets 中添加：
- Name: `NAMESPACE`
- Value: `your-namespace`

然后修改 workflow：

```yaml
env:
  NAMESPACE: ${{ secrets.NAMESPACE || 'library' }}
```

---

## 命名空间查看方法

### 通过阿里云控制台
1. 访问 https://cr.console.aliyun.com/
2. 左侧菜单 → **命名空间**
3. 查看你的命名空间列表

### 通过 API
```bash
# 登录后
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com

# 查看命名空间（需要先创建镜像）
curl https://cr.console.aliyun.com/repository/api/namespaces
```

---

## 常见错误

### 错误1：`repository does not exist`

**原因**：命名空间不存在

**解决**：
1. 在阿里云控制台创建命名空间
2. 或修改 workflow 使用已存在的命名空间

### 错误2：`insufficient_scope: authorization failed`

**原因**：使用了登录密码而非访问令牌

**解决**：使用 AccessKey 或 Registry密码

### 错误3：`denied: access denied`

**原因**：AccessKey 权限不足

**解决**：确保 RAM 用户有 `AliyunContainerRegistryFullAccess` 权限

---

## RAM 用户配置（推荐）

为了安全，建议创建专门的RAM用户：

1. 访问 [RAM控制台](https://ram.console.aliyun.com/)
2. 创建用户 → 生成 AccessKey
3. 添加权限：
   - `AliyunContainerRegistryFullAccess`
4. 保存 AccessKey ID 和 AccessKey Secret
5. 在 GitHub Secrets 中使用：
   - `ALIYUN_USERNAME`: AccessKey ID
   - `ALIYUN_PASSWORD`: AccessKey Secret

---

## 验证配置

本地测试阿里云登录：

```bash
# 使用访问令牌测试
docker login --username=乐观山里娃 registry.cn-hangzhou.aliyuncs.com
# 输入访问令牌/AccessKey Secret

# 测试推送
docker pull alpine:latest
docker tag alpine:latest registry.cn-hangzhou.aliyuncs.com/library/test:latest
docker push registry.cn-hangzhou.aliyuncs.com/library/test:latest
```

如果本地推送成功，说明配置正确，GitHub Actions 也能成功。
