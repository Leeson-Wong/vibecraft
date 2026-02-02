# Vibecraft 镜像推送脚本 (PowerShell)
# 推送到阿里云容器镜像服务

param(
    [Parameter(Mandatory=$false, HelpMessage="命名空间，默认: wls_gdd")]
    [string]$Namespace = "wls_gdd",

    [Parameter(Mandatory=$false, HelpMessage="镜像版本标签，默认: latest")]
    [string]$Tag = "latest",

    [Parameter(Mandatory=$false, HelpMessage="是否同时推送 stable 标签")]
    [switch]$PushStable
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Info {
    Write-ColorOutput Green "[INFO] $args"
}

function Warn {
    Write-ColorOutput Yellow "[WARN] $args"
}

function ErrorMsg {
    Write-ColorOutput Red "[ERROR] $args"
}

# 阿里云配置
$REGISTRY = "registry.cn-hangzhou.aliyuncs.com"
$USERNAME = "乐观山里娃"
$IMAGE_NAME = "vibecraft"
$DEFAULT_NAMESPACE = "wls_gdd"
$FULL_IMAGE = "${REGISTRY}/${Namespace}/${IMAGE_NAME}"

# 显示横幅
Write-Output ""
Write-ColorOutput Cyan "╔════════════════════════════════════════════════════════════╗"
Write-ColorOutput Cyan "║     推送 Vibecraft 镜像到阿里云容器镜像服务                   ║"
Write-ColorOutput Cyan "╚════════════════════════════════════════════════════════════╝"
Write-Output ""

Info "配置信息:"
Write-Output "  仓库地址: $REGISTRY"
Write-Output "  用户名: $USERNAME"
Write-Output "  命名空间: $Namespace"
Write-Output "  镜像名称: $IMAGE_NAME"
Write-Output "  版本标签: $Tag"
Write-Output "  完整路径: ${FULL_IMAGE}:${Tag}"
Write-Output ""

# 检查Docker是否安装
try {
    $null = Get-Command docker -ErrorAction Stop
} catch {
    ErrorMsg "Docker未安装，请先安装Docker"
    exit 1
}

# 检查镜像是否存在
Info "检查本地镜像..."
$imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "^vibecraft:latest$"

if (-not $imageExists) {
    Warn "本地镜像 vibecraft:latest 不存在"
    $build = Read-Host "是否现在构建? (Y/n)"
    if ($build -ne "n") {
        Info "构建镜像..."
        docker build -t vibecraft:latest .
        if ($LASTEXITCODE -ne 0) {
            ErrorMsg "镜像构建失败"
            exit 1
        }
        Info "✓ 镜像构建成功"
    } else {
        exit 0
    }
} else {
    Info "✓ 本地镜像已存在"
}

# 登录阿里云
Write-Output ""
Info "登录阿里云容器镜像服务..."
Write-Output "  用户名: $USERNAME"
Write-Output "  仓库: $REGISTRY"
Write-Output ""

docker login --username $USERNAME $REGISTRY

if ($LASTEXITCODE -ne 0) {
    ErrorMsg "登录失败，请检查用户名和密码"
    exit 1
}

Info "✓ 登录成功"

# 标记镜像
Write-Output ""
Info "标记镜像..."
docker tag vibecraft:latest "${FULL_IMAGE}:${Tag}"

if ($LASTEXITCODE -ne 0) {
    ErrorMsg "标记镜像失败"
    exit 1
}

Info "✓ 镜像标记完成: ${FULL_IMAGE}:${Tag}"

# 推送镜像
Write-Output ""
Info "推送镜像到阿里云..."
Write-Output "  这可能需要几分钟，取决于网络速度..."
Write-Output ""

docker push "${FULL_IMAGE}:${Tag}"

if ($LASTEXITCODE -ne 0) {
    ErrorMsg "推送失败"
    exit 1
}

Info "✓ 推送成功: ${FULL_IMAGE}:${Tag}"

# 如果需要，同时推送 stable 标签
if ($PushStable) {
    Write-Output ""
    Info "标记并推送 stable 版本..."
    docker tag vibecraft:latest "${FULL_IMAGE}:stable"
    docker push "${FULL_IMAGE}:stable"

    if ($LASTEXITCODE -eq 0) {
        Info "✓ 推送成功: ${FULL_IMAGE}:stable"
    }
}

# 显示使用说明
Write-Output ""
Write-ColorOutput Cyan "╔════════════════════════════════════════════════════════════╗"
Write-ColorOutput Cyan "║                  推送成功!                                   ║"
Write-ColorOutput Cyan "╚════════════════════════════════════════════════════════════╝"
Write-Output ""

Info "镜像地址:"
Write-Output "  ${FULL_IMAGE}:${Tag}"
Write-Output ""

Info "拉取镜像:"
Write-Output "  docker pull ${FULL_IMAGE}:${Tag}"
Write-Output ""

Info "运行容器:"
Write-Output "  docker run -d \\"
Write-Output "    --name vibecraft \\"
Write-Output "    -p 4002:4002 \\"
Write-Output "    -p 4003:4003 \\"
Write-Output "    -v vibecraft-data:/home/vibecraft/.vibecraft \\"
Write-Output "    -e ALLOWED_ORIGINS=\\"http://localhost:4002,http://YOUR-IP:4002\\" \\"
Write-Output "    ${FULL_IMAGE}:${Tag}"
Write-Output ""

Info "常用操作:"
Write-Output "  • 查看镜像: docker images | Select-String vibecraft"
Write-Output "  • 删除本地镜像: docker rmi ${FULL_IMAGE}:${Tag}"
Write-Output "  • 重新登录: docker login --username $USERNAME $REGISTRY"
Write-Output ""
