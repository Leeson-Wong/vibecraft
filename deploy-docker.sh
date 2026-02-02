#!/bin/bash

# Vibecraft Docker 部署脚本
# 使用方法: ./deploy-docker.sh [OPTIONS]
#
# 选项:
#   -o, --origin URL      公网访问地址 (如: http://47.96.93.247:4002)
#   -p, --port PORT       前端端口 (默认: 4002)
#   -w, --ws-port PORT    WebSocket端口 (默认: 4003)
#   -d, --debug           启用调试模式
#   -b, --build-only      仅构建镜像，不启动容器
#   -h, --help            显示帮助信息

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认值
FRONTEND_PORT=4002
WS_PORT=4003
DEBUG=false
BUILD_ONLY=false
PUBLIC_ORIGIN=""

# 显示横幅
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Vibecraft Docker 部署脚本                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--origin)
            PUBLIC_ORIGIN="$2"
            shift 2
            ;;
        -p|--port)
            FRONTEND_PORT="$2"
            shift 2
            ;;
        -w|--ws-port)
            WS_PORT="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -b|--build-only)
            BUILD_ONLY=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  -o, --origin URL      公网访问地址 (如: http://47.96.93.247:4002)"
            echo "  -p, --port PORT       前端端口 (默认: 4002)"
            echo "  -w, --ws-port PORT    WebSocket端口 (默认: 4003)"
            echo "  -d, --debug           启用调试模式"
            echo "  -b, --build-only      仅构建镜像"
            echo "  -h, --help            显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                                    # 本地访问"
            echo "  $0 -o http://47.96.93.247:4002        # 公网访问"
            echo "  $0 -o https://your-domain.com        # 域名访问"
            echo "  $0 -p 8080 -w 8081                    # 自定义端口"
            exit 0
            ;;
        *)
            error "未知参数: $1"
            echo "使用 -h 查看帮助信息"
            exit 1
            ;;
    esac
done

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    error "Docker未安装，请先安装Docker"
    exit 1
fi

info "Docker已安装: $(docker --version)"

# 构建允许的来源列表
ALLOWED_ORIGINS="http://localhost:${FRONTEND_PORT},http://127.0.0.1:${FRONTEND_PORT}"

if [ -n "$PUBLIC_ORIGIN" ]; then
    ALLOWED_ORIGINS="${ALLOWED_ORIGINS},${PUBLIC_ORIGIN}"
    info "✓ 已添加公网地址到允许列表: $PUBLIC_ORIGIN"
else
    warn "未指定公网地址 (-o/--origin)，仅允许本地访问"
    warn "如需公网访问，请使用: -o http://your-ip:port"
fi

# 显示配置
echo ""
info "部署配置:"
echo "  前端端口: $FRONTEND_PORT"
echo "  WebSocket端口: $WS_PORT"
echo "  允许的来源: $ALLOWED_ORIGINS"
echo "  调试模式: $DEBUG"
echo ""

# 构建镜像
info "开始构建Docker镜像..."
docker build -t vibecraft:latest .

if [ $? -ne 0 ]; then
    error "镜像构建失败"
    exit 1
fi

info "✓ 镜像构建成功"

if [ "$BUILD_ONLY" = true ]; then
    info "仅构建模式，跳过容器启动"
    exit 0
fi

# 检查是否已存在容器
if docker ps -a --format '{{.Names}}' | grep -q '^vibecraft$'; then
    warn "检测到已存在的vibecraft容器"
    read -p "是否删除并重新创建? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "删除旧容器..."
        docker stop vibecraft 2>/dev/null || true
        docker rm vibecraft 2>/dev/null || true
    else
        info "保留现有容器，退出部署"
        exit 0
    fi
fi

# 创建数据卷
info "创建数据卷..."
docker volume create vibecraft-data 2>/dev/null || true

# 启动容器
info "启动容器..."
docker run -d \
    --name vibecraft \
    --restart unless-stopped \
    -p "${FRONTEND_PORT}:4002" \
    -p "${WS_PORT}:4003" \
    -v vibecraft-data:/home/vibecraft/.vibecraft \
    -e VIBECRAFT_PORT="${WS_PORT}" \
    -e VIBECRAFT_CLIENT_PORT="${FRONTEND_PORT}" \
    -e ALLOWED_ORIGINS="${ALLOWED_ORIGINS}" \
    -e VIBECRAFT_DEBUG="${DEBUG}" \
    vibecraft:latest

if [ $? -ne 0 ]; then
    error "容器启动失败"
    exit 1
fi

# 等待服务启动
info "等待服务启动..."
MAX_WAIT=30
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))

    if curl -s -f "http://localhost:${WS_PORT}/health" > /dev/null 2>&1; then
        break
    fi
done

# 最终检查
if curl -s -f "http://localhost:${WS_PORT}/health" > /dev/null 2>&1; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  部署成功!                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    info "访问地址:"
    echo "  • 本地访问: http://localhost:${FRONTEND_PORT}"
    if [ -n "$PUBLIC_ORIGIN" ]; then
        echo "  • 公网访问: ${PUBLIC_ORIGIN}"
    fi
    echo ""
    info "常用命令:"
    echo "  • 查看日志: docker logs -f vibecraft"
    echo "  • 停止服务: docker stop vibecraft"
    echo "  • 启动服务: docker start vibecraft"
    echo "  • 重启服务: docker restart vibecraft"
    echo "  • 删除容器: docker rm -f vibecraft"
    echo ""
else
    warn "服务可能还在启动中，请稍后访问"
    warn "健康检查地址: http://localhost:${WS_PORT}/health"
    echo ""
    info "查看日志以排查问题:"
    echo "docker logs vibecraft"
    echo ""
fi
