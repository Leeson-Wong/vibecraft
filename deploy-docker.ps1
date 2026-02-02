# Vibecraft Docker 部署脚本 (PowerShell)
# 使用方法: .\deploy-docker.ps1 -PublicOrigin "http://47.96.93.247:4002"

param(
    [Parameter(Mandatory=$false, HelpMessage="公网访问地址，例如: http://47.96.93.247:4002 或 https://your-domain.com")]
    [string]$PublicOrigin = "",

    [Parameter(Mandatory=$false, HelpMessage="前端端口，默认: 4002")]
    [int]$FrontendPort = 4002,

    [Parameter(Mandatory=$false, HelpMessage="WebSocket服务端口，默认: 4003")]
    [int]$WsPort = 4003,

    [Parameter(Mandatory=$false, HelpMessage="启用调试模式")]
    [switch]$Debug,

    [Parameter(Mandatory=$false, HelpMessage="仅构建镜像，不启动容器")]
    [switch]$BuildOnly
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

# 显示横幅
Write-Output ""
Write-ColorOutput Cyan "╔════════════════════════════════════════════════════════════╗"
Write-ColorOutput Cyan "║           Vibecraft Docker 部署脚本                        ║"
Write-ColorOutput Cyan "╚════════════════════════════════════════════════════════════╝"
Write-Output ""

# 检查Docker是否安装
try {
    $null = Get-Command docker -ErrorAction Stop
    Info "Docker已安装: $(docker --version)"
} catch {
    ErrorMsg "Docker未安装，请先安装Docker Desktop"
    exit 1
}

# 构建允许的来源列表
$allowedOrigins = @("http://localhost:$FrontendPort", "http://127.0.0.1:$FrontendPort")

if (-not [string]::IsNullOrEmpty($PublicOrigin)) {
    $allowedOrigins += $PublicOrigin
    Info "✓ 已添加公网地址到允许列表: $PublicOrigin"
} else {
    Warn "未指定公网地址 (-PublicOrigin)，仅允许本地访问"
    Warn "如需公网访问，请使用: -PublicOrigin `"http://your-ip:port`""
}

$ALLOWED_ORIGINS = $allowedOrigins -join ","

# 显示配置
Write-Output ""
Info "部署配置:"
Write-Output "  前端端口: $FrontendPort"
Write-Output "  WebSocket端口: $WsPort"
Write-Output "  允许的来源: $ALLOWED_ORIGINS"
Write-Output "  调试模式: $Debug"
Write-Output ""

# 构建镜像
Info "开始构建Docker镜像..."
docker build -t vibecraft:latest .

if ($LASTEXITCODE -ne 0) {
    ErrorMsg "镜像构建失败"
    exit 1
}

Info "✓ 镜像构建成功"

if ($BuildOnly) {
    Info "仅构建模式，跳过容器启动"
    exit 0
}

# 检查是否已存在容器
$existingContainer = docker ps -a --format "{{.Names}}" | Select-String -Pattern "^vibecraft$"
if ($existingContainer) {
    Warn "检测到已存在的vibecraft容器"
    $confirm = Read-Host "是否删除并重新创建? (y/N)"
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Info "删除旧容器..."
        docker stop vibecraft 2>$null | Out-Null
        docker rm vibecraft 2>$null | Out-Null
    } else {
        Info "保留现有容器，退出部署"
        exit 0
    fi
}

# 创建数据卷
Info "创建数据卷..."
docker volume create vibecraft-data 2>$null | Out-Null

# 准备环境变量
$envVars = @{
    "VIBECRAFT_PORT" = $FrontendPort
    "VIBECRAFT_WS_PORT" = $WsPort
    "ALLOWED_ORIGINS" = $ALLOWED_ORIGINS
    "VIBECRAFT_DEBUG" = $Debug.ToString().ToLower()
}

# 构建 docker run 命令的参数
$dockerArgs = @(
    "run", "-d",
    "--name", "vibecraft",
    "--restart", "unless-stopped",
    "-p", "$FrontendPort`:4002",
    "-p", "$WsPort`:4003",
    "-v", "vibecraft-data:/home/vibecraft/.vibecraft"
)

foreach ($var in $envVars.GetEnumerator()) {
    $dockerArgs += "-e"
    $dockerArgs += "$($var.Key)=$($var.Value)"
}

$dockerArgs += "vibecraft:latest"

Info "启动容器..."
& docker $dockerArgs

if ($LASTEXITCODE -ne 0) {
    ErrorMsg "容器启动失败"
    exit 1
}

# 等待服务启动
Info "等待服务启动..."
$maxWait = 30
$waited = 0
while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 2
    $waited += 2

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$WsPort/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            break
        }
    } catch {
        # 继续等待
    }
}

# 最终检查
try {
    $response = Invoke-WebRequest -Uri "http://localhost:$WsPort/health" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Output ""
        Write-ColorOutput Cyan "╔════════════════════════════════════════════════════════════╗"
        Write-ColorOutput Cyan "║                  部署成功!                                   ║"
        Write-ColorOutput Cyan "╚════════════════════════════════════════════════════════════╝"
        Write-Output ""
        Info "访问地址:"
        Write-Output "  • 本地访问: http://localhost:$FrontendPort"
        if (-not [string]::IsNullOrEmpty($PublicOrigin)) {
            $originWithoutPort = $PublicOrigin -replace ':4002$', ''
            Write-Output "  • 公网访问: $originWithoutPort"
        }
        Write-Output ""
        Info "常用命令:"
        Write-Output "  • 查看日志: docker logs -f vibecraft"
        Write-Output "  • 停止服务: docker stop vibecraft"
        Write-Output "  • 启动服务: docker start vibecraft"
        Write-Output "  • 重启服务: docker restart vibecraft"
        Write-Output "  • 删除容器: docker rm -f vibecraft"
        Write-Output ""
    }
} catch {
    Warn "服务可能还在启动中，请稍后访问"
    Warn "健康检查地址: http://localhost:$WsPort/health"
    Write-Output ""
    Info "查看日志以排查问题:"
    Write-Output "docker logs vibecraft"
    Write-Output ""
}
