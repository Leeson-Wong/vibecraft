#!/bin/bash

# Vibecraft 镜像推送脚本 (Bash)
# 推送到阿里云容器镜像服务

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
NAMESPACE="library"
TAG="latest"
PUSH_STABLE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -s|--stable)
            PUSH_STABLE=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  -n, --namespace NAMESPACE  命名空间 (默认: library)"
            echo "  -t, --tag TAG             版本标签 (默认: latest)"
            echo "  -s, --stable              同时推送 stable 标签"
            echo "  -h, --help                显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                          # 推送到 library:latest"
            echo "  $0 -n mynamespace -t v1.0.0 # 推送到 mynamespace:v1.0.0"
            echo "  $0 -s                       # 推送到 latest 和 stable"
            exit 0
            ;;
        *)
            error "未知参数: $1"
            echo "使用 -h 查看帮助信息"
            exit 1
            ;;
    esac
done

# 阿里云配置
REGISTRY="registry.cn-hangzhou.aliyuncs.com"
USERNAME="乐观山里娃"
IMAGE_NAME="vibecraft"
FULL_IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}"

# 显示横幅
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     推送 Vibecraft 镜像到阿里云容器镜像服务                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

info "配置信息:"
echo "  仓库地址: $REGISTRY"
echo "  用户名: $USERNAME"
echo "  命名空间: $NAMESPACE"
echo "  镜像名称: $IMAGE_NAME"
echo "  版本标签: $TAG"
echo "  完整路径: ${FULL_IMAGE}:${TAG}"
echo ""

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    error "Docker未安装，请先安装Docker"
    exit 1
fi

# 检查镜像是否存在
info "检查本地镜像..."
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^vibecraft:latest$"; then
    info "✓ 本地镜像已存在"
else
    warn "本地镜像 vibecraft:latest 不存在"
    read -p "是否现在构建? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        info "构建镜像..."
        docker build -t vibecraft:latest .
        info "✓ 镜像构建成功"
    else
        exit 0
    fi
fi

# 登录阿里云
echo ""
info "登录阿里云容器镜像服务..."
echo "  用户名: $USERNAME"
echo "  仓库: $REGISTRY"
echo ""

docker login --username "$USERNAME" "$REGISTRY"

if [ $? -ne 0 ]; then
    error "登录失败，请检查用户名和密码"
    exit 1
fi

info "✓ 登录成功"

# 标记镜像
echo ""
info "标记镜像..."
docker tag vibecraft:latest "${FULL_IMAGE}:${TAG}"

info "✓ 镜像标记完成: ${FULL_IMAGE}:${TAG}"

# 推送镜像
echo ""
info "推送镜像到阿里云..."
echo "  这可能需要几分钟，取决于网络速度..."
echo ""

docker push "${FULL_IMAGE}:${TAG}"

if [ $? -ne 0 ]; then
    error "推送失败"
    exit 1
fi

info "✓ 推送成功: ${FULL_IMAGE}:${TAG}"

# 如果需要，同时推送 stable 标签
if [ "$PUSH_STABLE" = true ]; then
    echo ""
    info "标记并推送 stable 版本..."
    docker tag vibecraft:latest "${FULL_IMAGE}:stable"
    docker push "${FULL_IMAGE}:stable"
    info "✓ 推送成功: ${FULL_IMAGE}:stable"
fi

# 显示使用说明
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  推送成功!                                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

info "镜像地址:"
echo "  ${FULL_IMAGE}:${TAG}"
echo ""

info "拉取镜像:"
echo "  docker pull ${FULL_IMAGE}:${TAG}"
echo ""

info "运行容器:"
echo "  docker run -d \\"
echo "    --name vibecraft \\"
echo "    -p 4002:4002 \\"
echo "    -p 4003:4003 \\"
echo "    -v vibecraft-data:/home/vibecraft/.vibecraft \\"
echo "    -e ALLOWED_ORIGINS=\"http://localhost:4002,http://YOUR-IP:4002\" \\"
echo "    ${FULL_IMAGE}:${TAG}"
echo ""

info "常用操作:"
echo "  • 查看镜像: docker images | grep vibecraft"
echo "  • 删除本地镜像: docker rmi ${FULL_IMAGE}:${TAG}"
echo "  • 重新登录: docker login --username $USERNAME $REGISTRY"
echo ""
