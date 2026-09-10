#!/bin/bash
# Mac 硬件温度一键检测脚本
# 功能：检查 iStats → 自动安装 → 检测温度 → 输出结果
# 用法：SUDO_PASSWORD="密码" bash check_temp.sh [full|basic]
#   full  - 完整检测（所有传感器），默认
#   basic - 仅基础检测（CPU+风扇+电池）

set -e

MODE="${1:-full}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. 检查系统
info "检查系统环境..."
if [ "$(uname -s)" != "Darwin" ]; then
    error "本脚本仅支持 macOS，当前系统：$(uname -s)"
    exit 1
fi
info "系统：macOS ✓"

# 2. 检查 iStats
info "检查 iStats 是否已安装..."
if command -v istats &> /dev/null; then
    info "iStats 已安装：$(istats --version 2>/dev/null || echo '已安装') ✓"
else
    warn "iStats 未安装，开始自动安装..."

    # 检查 gem
    if ! command -v gem &> /dev/null; then
        error "未找到 gem 命令，请先安装 Ruby（macOS 通常自带）"
        exit 1
    fi

    # 安装 iStats
    if [ -n "$SUDO_PASSWORD" ]; then
        info "使用提供的密码安装..."
        echo "$SUDO_PASSWORD" | sudo -S gem install iStats 2>&1 || {
            error "安装失败，可能密码错误或网络问题"
            exit 1
        }
    else
        info "请输入 sudo 密码（输入时不显示）："
        sudo gem install iStats 2>&1 || {
            error "安装失败"
            exit 1
        }
    fi

    # 验证安装
    if command -v istats &> /dev/null; then
        info "iStats 安装成功 ✓"
    else
        error "安装后仍找不到 istats 命令，请检查 PATH 配置"
        exit 1
    fi
fi

# 3. 检测温度
echo ""
info "开始检测硬件温度..."
echo "========================================"

if [ "$MODE" = "full" ]; then
    info "执行完整检测（所有传感器）..."
    istats scan 2>&1 || istats 2>&1
else
    info "执行基础检测（CPU + 风扇 + 电池）..."
    istats 2>&1
fi

echo "========================================"
echo ""
info "检测完成。如需解读温度是否正常，请参考 references/temp-ranges.md"
